local _, WTF = ...

local USAGE = "Use /grim, /grim test (sample alerts), /grim shards, /grim stones, /grim unlock, /grim lock, "
    .. "/grim reset, /grim reset_focus, or for testing /grim debug_log, debug_log_save, debug_log_reset, debug_checks, "
    .. "debug_restrictions, debug_alerts, debug_reminders, "
    .. "debug_threat, debug_pet, debug_procs, debug_cooldowns, debug_shield, debug_shards, debug_stones, "
    .. "debug_tracker, debug_predict, debug_control."
local UNAVAILABLE = "Grimoire is unavailable. Check its login message."

-- Each command is one word; "" opens the settings. Handlers live in the other
-- files. Diagnostics also run when Grimoire is unavailable, to help explain why.
-- Grimoire keeps the read-only diagnostics (they only print); debug_delete,
-- debug_click, debug_announce, and debug_emote are gone.
local COMMANDS = {
    [""] = {handler = "OpenSettings"},
    options = {handler = "OpenSettings"},
    shards = {handler = "ReportShardStatus"},
    debug_restrictions = {handler = "ReportRestrictions", always = true},
    debug_shards = {handler = "ReportShardDebug", always = true},
    reset = {handler = "ResetPositions"},
    reset_focus = {handler = "ResetFocusWorks"},
    unlock = {handler = "Unlock"},
    lock = {handler = "Lock"},
    stones = {handler = "ReportStoneStatus"},
    debug_stones = {handler = "ReportStoneDebug"},
    debug_tracker = {handler = "ReportTrackerDebug", always = true},
    debug_predict = {handler = "ReportPredictDebug"},
    debug_control = {handler = "ReportControlDebug"},
    test = {handler = "TestAlerts"},
    debug_checks = {handler = "ReportForeverChecks", always = true},
    debug_log = {handler = "ReportDiagnostics"},
    debug_log_save = {handler = "SaveDiagnostics"},
    debug_log_reset = {handler = "ResetDiagnostics"},
    debug_alerts = {handler = "ReportAlertsDebug"},
    debug_reminders = {handler = "ReportRemindersDebug"},
    debug_threat = {handler = "ReportThreatDebug"},
    debug_pet = {handler = "ReportPetDebug"},
    debug_procs = {handler = "ReportProcsDebug"},
    debug_cooldowns = {handler = "ReportCooldownsDebug"},
    debug_shield = {handler = "ReportShieldDebug"},
}

function WTF.ParseCommand(message)
    if type(message) ~= "string" then
        return nil, USAGE
    end
    local command = message:match("^%s*(.-)%s*$"):lower()
    if command:find("%s") or not COMMANDS[command] then
        return nil, USAGE
    end
    return command
end

function WTF.HandleCommand(message)
    local command, usage = WTF.ParseCommand(message)
    if not command then
        WTF.Report(usage)
        return
    end
    local entry = COMMANDS[command]
    if not WTF.available and not entry.always then
        WTF.Report(UNAVAILABLE)
        return
    end
    WTF[entry.handler]()
end
