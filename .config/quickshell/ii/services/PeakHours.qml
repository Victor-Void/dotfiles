pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool deepseekPeak: false
    property bool anthropicPeak: false
    property bool started: false

    property string deepseekLine: ""
    property string anthropicLine: ""
    property string deepseekStatus: ""
    property string anthropicStatus: ""

    readonly property string soundFile: "$HOME/Downloads/ghost_of_tsushima.mp3"

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

    // DeepSeek peak: 01:00-04:00 & 06:00-10:00 UTC (off-peak = half price)
    function deepseekPeakAt(date) {
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
        const mins = date.getUTCHours() * 60 + date.getUTCMinutes();
        const boundaries = [60, 240, 360, 600];
        for (let i = 0; i < boundaries.length; ++i) {
            if (boundaries[i] > mins) {
                return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 0, boundaries[i]));
            }
        }
        return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1, 1, 0));
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

        if (root.started) {
            if (newDs !== root.deepseekPeak) root.notifyDeepseek(newDs, now);
            if (newAn !== root.anthropicPeak) root.notifyAnthropic(newAn, now);
        }

        root.deepseekPeak = newDs;
        root.anthropicPeak = newAn;
        root.started = true;

        const dsW1 = root.formatMinutes(root.utcHourToIstMinutes(1));
        const dsW1e = root.formatMinutes(root.utcHourToIstMinutes(4));
        const dsW2 = root.formatMinutes(root.utcHourToIstMinutes(6));
        const dsW2e = root.formatMinutes(root.utcHourToIstMinutes(10));
        const anStart = root.formatMinutes(root.ptHourToIstMinutes(5));
        const anEnd = root.formatMinutes(root.ptHourToIstMinutes(11));

        root.deepseekLine = "Peak " + dsW1 + "-" + dsW1e + " & " + dsW2 + "-" + dsW2e + " IST";
        root.anthropicLine = "Peak " + anStart + "-" + anEnd + " IST weekdays";
        root.deepseekStatus = root.deepseekPeak ? "Peak" : "Off Peak";
        root.anthropicStatus = root.anthropicPeak ? "Peak" : "Off Peak";

        root.scheduleNext();
    }

    function load() {
        root.started = false;
        root.update();
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
        Quickshell.execDetached(["bash", "-c", `ffplay -nodisp -autoexit -volume 80 "$HOME/Downloads/ghost_of_tsushima.mp3"`]);
    }

    readonly property Timer transitionTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: root.update()
    }
}
