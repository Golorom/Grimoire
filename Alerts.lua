local _, WTF = ...

-- Grimoire: the alert window. Short warnings for you only, in a slim window
-- of their own (not a chat tab, so any chat AddOn or none works): a line
-- shows the moment it comes, stays for the hold time, then fades out slowly.
-- Lines are left-aligned on a dark panel (25% opaque by default, a setting)
-- that appears with a line and fades with the newest one.
-- Nothing is ever sent to other players. The window takes no mouse while
-- locked, so it never blocks clicks on the world; unlocked, it shows sample
-- lines and an outline to drag.
--
-- WTF.Alert(key, text, level, options): level "info" (white), "warn"
-- (yellow), or "danger" (red); the same key shows at most once per
-- options.throttle seconds (default THROTTLE); options.sound plays a game
-- sound (a SOUNDKIT name, or {kit = name or ID} / {file = file ID}) when
-- sounds are on. With the window switched off, a line goes to chat instead;
-- with "Also print in chat" on, to both.

local HOLDER_WIDTH, LINE_HEIGHT, HOLDER_PADDING = 340, 22, 12
local TEXT_INSET_X, TEXT_INSET_Y = 10, 6
local DEFAULT_POINT = {"CENTER", "CENTER", 0, 210}
local THROTTLE = 10
local HISTORY = 20
local COLORS = {info = {1, 1, 1}, warn = {1, 0.82, 0}, danger = {1, 0.25, 0.25}}
local SAMPLES = {
    {"Sample: Demon Skin missing. Click the icon.", "warn"},
    {"Sample: Aggro! Wendigo is on you.", "danger"},
    {"Sample: Death Coil ready.", "info"},
}

WTF.ALERT_HOLD_MIN, WTF.ALERT_HOLD_MAX, WTF.DEFAULT_ALERT_HOLD = 2, 30, 8
WTF.ALERT_FADE_MIN, WTF.ALERT_FADE_MAX, WTF.DEFAULT_ALERT_FADE = 1, 10, 4
WTF.ALERT_LINES_MIN, WTF.ALERT_LINES_MAX, WTF.DEFAULT_ALERT_LINES = 2, 8, 4
-- The panel's opacity in percent: 25 is 75% transparent.
WTF.ALERT_BACKGROUND_MIN, WTF.ALERT_BACKGROUND_MAX, WTF.DEFAULT_ALERT_BACKGROUND = 0, 100, 25

local alerts = {last = {}, history = {}, lastAt = nil}
local holder, log, panel

-- The saved alert settings, repaired; Core calls this from SanitizeDB.
function WTF.SanitizeAlerts(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    return {
        enabled = saved.enabled ~= false,
        chat = saved.chat == true,
        sounds = saved.sounds ~= false,
        position = sanitizePosition(saved.position),
        scale = WTF.SanitizeFrameScale(saved.scale),
        hold = WTF.SanitizeWhole(saved.hold, WTF.ALERT_HOLD_MIN, WTF.ALERT_HOLD_MAX, WTF.DEFAULT_ALERT_HOLD),
        fade = WTF.SanitizeWhole(saved.fade, WTF.ALERT_FADE_MIN, WTF.ALERT_FADE_MAX, WTF.DEFAULT_ALERT_FADE),
        lines = WTF.SanitizeWhole(saved.lines, WTF.ALERT_LINES_MIN, WTF.ALERT_LINES_MAX, WTF.DEFAULT_ALERT_LINES),
        background = WTF.SanitizeWhole(saved.background, WTF.ALERT_BACKGROUND_MIN, WTF.ALERT_BACKGROUND_MAX,
            WTF.DEFAULT_ALERT_BACKGROUND),
    }
end

-- A game sound: a SOUNDKIT name or ID, or a sound file ID. Never in a way
-- that can fail loudly: an unknown name plays nothing.
function WTF.PlayGameSound(sound)
    if not sound or not WTF.db.alerts.sounds then
        return
    end
    if type(sound) ~= "table" then
        sound = {kit = sound}
    end
    if sound.file and type(PlaySoundFile) == "function" then
        PlaySoundFile(sound.file, "Master")
        return
    end
    local kit = sound.kit
    if type(kit) == "string" then
        kit = type(SOUNDKIT) == "table" and SOUNDKIT[kit] or sound.id
    end
    if type(kit) == "number" and type(PlaySound) == "function" then
        PlaySound(kit, "Master")
    end
end

local function Place()
    local position = WTF.db.alerts.position
    holder:ClearAllPoints()
    if position then
        holder:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        holder:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

local function ApplyLook()
    local settings = WTF.db.alerts
    log:SetTimeVisible(settings.hold)
    log:SetFadeDuration(settings.fade)
    log:SetMaxLines(settings.lines)
    holder:SetHeight(settings.lines * LINE_HEIGHT + HOLDER_PADDING)
    holder:SetScale(settings.scale / 100)
end

-- The panel: full opacity while the newest line holds, then down with it.
-- Its OnUpdate is set only while it fades.
local function PanelAlpha()
    local opacity = WTF.db.alerts.background / 100
    if not WTF.db.locked then
        return opacity
    end
    if not alerts.lastAt then
        return 0
    end
    local settings = WTF.db.alerts
    local left = alerts.lastAt + settings.hold + settings.fade - GetTime()
    if left <= 0 then
        return 0
    end
    return opacity * math.min(1, left / settings.fade)
end

local function UpdatePanel(self)
    local alpha = PanelAlpha()
    self:SetAlpha(alpha)
    if alpha <= 0 then
        self:Hide()
        self:SetScript("OnUpdate", nil)
    end
end

local function ShowPanel()
    if WTF.db.alerts.background <= 0 then
        panel:Hide()
        panel:SetScript("OnUpdate", nil)
        return
    end
    panel:Show()
    UpdatePanel(panel)
    if panel:IsShown() and WTF.db.locked then
        panel:SetScript("OnUpdate", UpdatePanel)
    end
end

local function AddLine(text, level)
    local color = COLORS[level] or COLORS.info
    log:AddMessage(text, color[1], color[2], color[3])
    alerts.lastAt = GetTime()
    ShowPanel()
end

function WTF.RefreshAlerts()
    if not holder then
        return
    end
    local unlocked = not WTF.db.locked
    holder.mover:SetShown(unlocked)
    holder:EnableMouse(unlocked)
    holder:SetShown(WTF.db.alerts.enabled or unlocked)
    ApplyLook()
    if unlocked and not alerts.samples then
        alerts.samples = true
        for _, sample in ipairs(SAMPLES) do
            AddLine(sample[1], sample[2])
        end
    elseif not unlocked then
        alerts.samples = false
    end
    if unlocked or (alerts.lastAt and PanelAlpha() > 0) then
        ShowPanel()
    else
        panel:Hide()
        panel:SetScript("OnUpdate", nil)
    end
end

function WTF.SetAlertsScale(percent)
    WTF.db.alerts.scale = WTF.SanitizeFrameScale(percent)
    if holder then
        WTF.ScaleKeepingCenter(holder, WTF.db.alerts.scale / 100)
    end
end

function WTF.ResetAlertsPosition()
    WTF.db.alerts.position = nil
    if holder then
        Place()
    end
end

-- The latest alerts, newest last, for /grim debug_alerts and the tests.
function WTF.AlertHistory()
    return alerts.history
end

function WTF.Alert(key, text, level, options)
    if type(text) ~= "string" or text == "" then
        return false
    end
    options = options or {}
    local now = GetTime()
    local throttle = options.throttle or THROTTLE
    key = key or text
    if alerts.last[key] and now - alerts.last[key] < throttle then
        return false
    end
    alerts.last[key] = now
    local history = alerts.history
    history[#history + 1] = {key = key, text = text, level = level or "info", time = now}
    if #history > HISTORY then
        table.remove(history, 1)
    end
    -- Grimoire 0.2.1: the diagnostics' alert log keeps the key's kind, not the text.
    if WTF.NoteAlertEvent then
        WTF.NoteAlertEvent(key, level)
    end
    local settings = WTF.db and WTF.db.alerts
    if settings and settings.enabled and log then
        AddLine(text, level)
        holder:Show()
        if settings.chat then
            WTF.Report(text)
        end
    else
        WTF.Report(text)
    end
    if options.sound and settings then
        WTF.PlayGameSound(options.sound)
    end
    return true
end

-- Forgets a key's throttle, so its next alert shows at once.
function WTF.ResetAlert(key)
    alerts.last[key] = nil
end

-- /grim test: one line of each kind, with a sound, past every throttle.
function WTF.TestAlerts()
    WTF.ResetAlert("test:info")
    WTF.ResetAlert("test:warn")
    WTF.ResetAlert("test:danger")
    WTF.Alert("test:info", "Test: Death Coil ready.", "info")
    WTF.Alert("test:warn", "Test: Demon Skin missing. Click the icon.", "warn")
    WTF.Alert("test:danger", "Test: Aggro! Wendigo is on you.", "danger", {sound = "RAID_WARNING"})
    if not WTF.db.alerts.enabled then
        WTF.Report("The alert window is off (Alerts page), so these went to chat.")
    end
end

function WTF.ReportAlertsDebug()
    WTF.Report(string.format("debug_alerts enabled=%s chat=%s sounds=%s hold=%d fade=%d lines=%d shown=%s",
        tostring(WTF.db.alerts.enabled), tostring(WTF.db.alerts.chat), tostring(WTF.db.alerts.sounds),
        WTF.db.alerts.hold, WTF.db.alerts.fade, WTF.db.alerts.lines, tostring(holder and holder:IsShown())))
    for _, entry in ipairs(alerts.history) do
        WTF.Report(string.format("debug_alerts %.0fs ago %s %s: %s", GetTime() - entry.time, entry.level,
            entry.key, entry.text))
    end
end

function WTF.InitializeAlerts()
    holder = CreateFrame("Frame", "GrimoireAlerts", UIParent)
    holder:SetSize(HOLDER_WIDTH, WTF.db.alerts.lines * LINE_HEIGHT + HOLDER_PADDING)
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    holder:RegisterForDrag("LeftButton")
    holder:SetScript("OnDragStart", WTF.BeginDrag)
    holder:SetScript("OnDragStop", WTF.EndDrag)
    WTF.RegisterMovable(holder, function(position) WTF.db.alerts.position = position end)
    holder.mover = WTF.CreateMover(holder)
    panel = CreateFrame("Frame", "GrimoireAlertsPanel", holder, "BackdropTemplate")
    panel:SetAllPoints()
    panel:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}})
    panel:SetBackdropColor(0, 0, 0, 1)
    panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    panel:EnableMouse(false)
    panel:Hide()
    holder.panel = panel
    log = CreateFrame("ScrollingMessageFrame", "GrimoireAlertsLog", holder)
    log:SetPoint("TOPLEFT", holder, "TOPLEFT", TEXT_INSET_X, -TEXT_INSET_Y)
    log:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -TEXT_INSET_X, TEXT_INSET_Y)
    log:SetFontObject(GameFontNormalLarge)
    log:SetJustifyH("LEFT")
    log:SetFading(true)
    log:EnableMouse(false)
    log:SetFrameLevel(panel:GetFrameLevel() + 2)
    holder.log = log
    WTF.alertsFrame = holder
    holder:SetScale(WTF.db.alerts.scale / 100)
    Place()
    WTF.RefreshAlerts()
end
