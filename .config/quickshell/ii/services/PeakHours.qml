pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool deepseekPeak: false
    property bool anthropicPeak: false

    // Last state this service observed, persisted to disk so a config reload (or
    // the shell being down across a transition) neither misses nor repeats an alert.
    property var lastState: null
    property bool stateLoaded: false
    readonly property string statePath: `${Directories.state}/user/peak_hours.json`
    readonly property string pricesPath: `${Directories.state}/user/peak_hours_prices.json`

    property string deepseekLine: ""
    property string anthropicLine: ""
    property string deepseekStatus: ""
    property string anthropicStatus: ""

    readonly property string soundFile: Quickshell.shellPath("assets/sounds/ghost_of_tsushima.mp3")

    // Model prices in USD per 1M tokens, as rows of [column, ...] cells.
    // Refreshed from the vendors' docs by scripts/peak-hours/update-prices.py;
    // these built-in rows are the fallback when no parsed JSON is available.
    property var priceOverrides: null

    readonly property var deepseekPriceRows: (root.priceOverrides && root.priceOverrides.deepseek) ? root.priceOverrides.deepseek : [
        { header: false, cells: ["", "off-peak", "peak"] },
        { header: true, cells: ["V4.1 Flash"] },
        { header: false, cells: ["cache hit", "0.003", "0.006"] },
        { header: false, cells: ["cache miss", "0.150", "0.300"] },
        { header: false, cells: ["output", "0.600", "1.200"] },
        { header: true, cells: ["V4 Pro"] },
        { header: false, cells: ["cache hit", "0.022", "0.044"] },
        { header: false, cells: ["cache miss", "0.660", "1.320"] },
        { header: false, cells: ["output", "1.980", "3.960"] },
    ]
    readonly property var anthropicPriceRows: (root.priceOverrides && root.priceOverrides.anthropic) ? root.priceOverrides.anthropic : [
        { header: false, cells: ["", "input", "output", "cache read"] },
        { header: false, cells: ["Opus 5", "5.00", "25.00", "0.50"] },
        { header: false, cells: ["Sonnet 5", "2.00", "10.00", "0.20"] },
        { header: false, cells: ["Haiku 4.5", "1.00", "5.00", "0.10"] },
    ]

    function buildPriceCells(rows) {
        const out = [];
        for (let r = 0; r < rows.length; ++r) {
            const row = rows[r];
            for (let c = 0; c < row.cells.length; ++c) {
                if (row.cells[c] === "") continue;
                out.push({ text: row.cells[c], row: r, col: c, header: row.header });
            }
        }
        return out;
    }

    readonly property var deepseekPriceCells: root.buildPriceCells(root.deepseekPriceRows)
    readonly property var anthropicPriceCells: root.buildPriceCells(root.anthropicPriceRows)

    function pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    // --- America/Los_Angeles DST helpers ---
    function isPacificDST(date) {
        const year = date.getUTCFullYear();
        const march = new Date(Date.UTC(year, 2, 1));
        const dstStart = new Date(Date.UTC(year, 2, 1 + ((7 - march.getUTCDay()) % 7) + 7, 10));
        const nov = new Date(Date.UTC(year, 10, 1));
        const dstEnd = new Date(Date.UTC(year, 10, 1 + ((7 - nov.getUTCDay()) % 7), 9));
        return date >= dstStart && date < dstEnd;
    }

    function pacificOffsetMs(date) {
        return (root.isPacificDST(date) ? 7 : 8) * 3600000;
    }

    // Fake-UTC Date whose getUTC* fields represent the PT wall clock
    function pacificWall(date) {
        return new Date(date.getTime() - root.pacificOffsetMs(date));
    }

    function istWall(date) {
        return new Date(date.getTime() + 5.5 * 3600000);
    }

    function formatHM(date) {
        return root.pad2(date.getUTCHours()) + ":" + root.pad2(date.getUTCMinutes());
    }

    function formatMinutes(mins) {
        return root.pad2(Math.floor(mins / 60)) + ":" + root.pad2(Math.round(mins % 60));
    }

    // DeepSeek peak: 01:00-04:00 & 06:00-10:00 UTC, Monday-Friday (off-peak = half price).
    function deepseekPeakAt(date) {
        const dow = date.getUTCDay();
        if (dow === 0 || dow === 6) return false;
        const h = date.getUTCHours();
        return (h >= 1 && h < 4) || (h >= 6 && h < 10);
    }

    // Anthropic peak: weekdays 05:00-11:00 PT
    function anthropicPeakAt(date) {
        const p = root.pacificWall(date);
        const dow = p.getUTCDay();
        if (dow === 0 || dow === 6) return false;
        const h = p.getUTCHours();
        return h >= 5 && h < 11;
    }

    function utcHourToIstMinutes(utcHour) {
        return (utcHour * 60 + 330) % 1440;
    }

    function ptHourToIstMinutes(ptHour) {
        const off = root.isPacificDST(new Date()) ? 7 : 8;
        return ((ptHour + off) * 60 + 330) % 1440;
    }

    function nextDeepseekTransition(date) {
        const hourMs = 3600000;
        const current = root.deepseekPeakAt(date);
        const start = (Math.floor(date.getTime() / hourMs) + 1) * hourMs;
        const limit = start + 4 * 24 * hourMs;
        for (let t = start; t < limit; t += hourMs) {
            if (root.deepseekPeakAt(new Date(t)) !== current) return new Date(t);
        }
        return new Date(limit);
    }

    function nextAnthropicTransition(date) {
        const p = root.pacificWall(date);
        if (root.anthropicPeakAt(date)) {
            const endWall = new Date(Date.UTC(p.getUTCFullYear(), p.getUTCMonth(), p.getUTCDate(), 11, 0));
            return new Date(endWall.getTime() + root.pacificOffsetMs(endWall));
        }
        for (let i = 0; i < 8; ++i) {
            const dayWall = new Date(Date.UTC(p.getUTCFullYear(), p.getUTCMonth(), p.getUTCDate() + i));
            const dow = dayWall.getUTCDay();
            if (dow >= 1 && dow <= 5) {
                const startWall = new Date(Date.UTC(p.getUTCFullYear(), p.getUTCMonth(), p.getUTCDate() + i, 5, 0));
                if (startWall > p) {
                    return new Date(startWall.getTime() + root.pacificOffsetMs(startWall));
                }
            }
        }
        return date;
    }

    function nextTransition(date) {
        const ds = root.nextDeepseekTransition(date);
        const an = root.nextAnthropicTransition(date);
        return ds.getTime() <= an.getTime() ? ds : an;
    }

    function scheduleNext() {
        const now = new Date();
        const delay = root.nextTransition(now).getTime() - now.getTime() + 1000;
        root.transitionTimer.interval = Math.max(1000, delay);
        root.transitionTimer.start();
    }

    function update() {
        const now = new Date();
        const newDs = root.deepseekPeakAt(now);
        const newAn = root.anthropicPeakAt(now);
        const prev = root.lastState;

        if (root.stateLoaded && prev) {
            if (newDs !== prev.deepseekPeak) root.notifyDeepseek(newDs, now);
            if (newAn !== prev.anthropicPeak) root.notifyAnthropic(newAn, now);
        }

        const changed = !prev || newDs !== prev.deepseekPeak || newAn !== prev.anthropicPeak;
        root.deepseekPeak = newDs;
        root.anthropicPeak = newAn;
        root.lastState = { deepseekPeak: newDs, anthropicPeak: newAn };
        if (root.stateLoaded && changed) root.persist();

        const dsW1 = root.formatMinutes(root.utcHourToIstMinutes(1));
        const dsW1e = root.formatMinutes(root.utcHourToIstMinutes(4));
        const dsW2 = root.formatMinutes(root.utcHourToIstMinutes(6));
        const dsW2e = root.formatMinutes(root.utcHourToIstMinutes(10));
        const anStart = root.formatMinutes(root.ptHourToIstMinutes(5));
        const anEnd = root.formatMinutes(root.ptHourToIstMinutes(11));

        root.deepseekLine = "Peak " + dsW1 + "-" + dsW1e + " & " + dsW2 + "-" + dsW2e + " IST weekdays";
        root.anthropicLine = "Peak " + anStart + "-" + anEnd + " IST weekdays";
        root.deepseekStatus = root.deepseekPeak ? "Peak" : "Off Peak";
        root.anthropicStatus = root.anthropicPeak ? "Peak" : "Off Peak";

        root.scheduleNext();
    }

    function persist() {
        stateFileView.setText(JSON.stringify(root.lastState));
    }

    function load() {
        stateFileView.reload();
    }

    function notifyDeepseek(peak, now) {
        const next = root.nextDeepseekTransition(now);
        const nextIst = root.formatHM(root.istWall(next));
        const summary = peak ? "DeepSeek API: Peak hours started" : "DeepSeek API: Off-peak hours started";
        const body = peak
            ? "Off-peak (half price) pricing ended.\nNext off-peak at " + nextIst + " IST."
            : "Off-peak pricing active (HALF PRICE) until " + nextIst + " IST.";
        root.notify(summary, body);
    }

    function notifyAnthropic(peak, now) {
        const next = root.nextAnthropicTransition(now);
        const nextIst = root.formatHM(root.istWall(next));
        const summary = peak ? "Anthropic Subscription: Peak hours started" : "Anthropic Subscription: Off-peak hours started";
        const body = peak
            ? "Claude usage limits are tighter until " + nextIst + " IST."
            : "Claude usage limits back to normal until " + nextIst + " IST.";
        root.notify(summary, body);
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", summary, body, "-a", "Peak Hours"]);
        Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", "-volume", "80", root.soundFile]);
    }

    readonly property Timer transitionTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: root.update()
    }

    FileView {
        id: stateFileView
        path: Qt.resolvedUrl(root.statePath)
        onLoaded: {
            try {
                root.lastState = JSON.parse(stateFileView.text());
            } catch (e) {
                root.lastState = null;
            }
            root.stateLoaded = true;
            root.update();
        }
        onLoadFailed: (error) => {
            root.lastState = null;
            root.stateLoaded = true;
            root.update();
        }
    }

    FileView {
        id: pricesFileView
        path: Qt.resolvedUrl(root.pricesPath)
        onLoaded: {
            try {
                root.priceOverrides = JSON.parse(pricesFileView.text());
            } catch (e) {
                root.priceOverrides = null;
            }
        }
        onLoadFailed: (error) => {
            root.priceOverrides = null;
        }
    }

    Component.onCompleted: {
        root.load();
        // Refresh prices from the vendors' docs at most once a day (the script
        // gates itself by the output file's age, so reloads don't re-fetch).
        Quickshell.execDetached([Quickshell.shellPath("scripts/peak-hours/update-prices.py")]);
    }
}
