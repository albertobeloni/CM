local CM = LibStub("AceAddon-3.0"):NewAddon("CM", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- /console taintLog 1
-- /console taintLog 0
-- /console scriptErrors 1
-- /console scriptErrors 0

--------------------------------------------------------------------------------
-- Modules
--------------------------------------------------------------------------------

local Damage = CM:NewModule("Damage")
local DamageBreakdown = CM:NewModule("DamageBreakdown")
local Healing = CM:NewModule("Healing")
local HealingBreakdown = CM:NewModule("HealingBreakdown")

--------------------------------------------------------------------------------
-- CM
--------------------------------------------------------------------------------

function CM:OnInitialize()
    self.database = LibStub("AceDB-3.0"):New("CMDB", {}, true)

    CM:RegisterChatCommand("cm", "NextModule")
    CM:RegisterChatCommand("mc", "PreviousModule")
end

function CM:OnEnable()
    ----------------------------------------------------------------------------
    -- Filters
    ----------------------------------------------------------------------------

    self.BITMASK_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE

    self.BITMASK_PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY
    self.BITMASK_RAID = COMBATLOG_OBJECT_AFFILIATION_RAID
    self.BITMASK_GROUP = bit.bor(self.BITMASK_MINE, self.BITMASK_PARTY, self.BITMASK_RAID)

    self.BITMASK_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET
    self.BITMASK_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN
    self.BITMASK_PETS = bit.bor(self.BITMASK_TYPE_PET, self.BITMASK_TYPE_GUARDIAN)

	self.BITMASK_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY
	self.BITMASK_NEUTRAL = COMBATLOG_OBJECT_REACTION_NEUTRAL
	self.BITMASK_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE

    self.BITMASK_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
	self.BITMASK_NPC = COMBATLOG_OBJECT_TYPE_NPC
	self.BITMASK_NONE = COMBATLOG_OBJECT_NONE

    ----------------------------------------------------------------------------
    -- Combat Events
    ----------------------------------------------------------------------------

    self.ALIASES = {
        DAMAGE_SHIELD = "SPELL_DAMAGE",
		DAMAGE_SPLIT = "SPELL_DAMAGE",
		DAMAGE_SHIELD_MISSED = "SPELL_MISSED"
    }

    self.PREFIXES = {
        SWING = {},
        RANGE = {
            "spellID",
            "spellName",
            "spellSchool"
        },
        SPELL = {
            "spellID",
            "spellName",
            "spellSchool"
        },
        SPELL_PERIODIC = {
            "spellID",
            "spellName",
            "spellSchool"
        },
        SPELL_BCMLDING = {
            "spellID",
            "spellName",
            "spellSchool"
        },
        ENVIRONMENTAL = {
            "environmentType"
        }
    }

    self.SUFFIXES = {
		DAMAGE = {
            "amount",
            "overkill",
            "school",
            "resisted",
            "blocked",
            "absorbed",
            "critical",
            "glancing",
            "crushing"
        },
		MISSED = {
            "missType",
            "offhand",
            "amount",
            "critical"
        },
		HEAL = {
            "amount",
            "overheal",
            "absorbed",
            "critical"
        },
		HEAL_ABSORBED = {
            "extraGCM",
            "extraName",
            "extraFlags",
            "extraRaidFlags",
            "extraSpellID",
            "extraSpellName",
            "extraSchool",
            "absorbed",
            "total"
        },
		ABSORBED = {
            "casterGCMD",
            "casterName",
            "casterFlags",
            "casterRaidFlags",
            "absorbSpellID",
            "absorbSpellname",
            "absorbSpellschool",
            "amount",
            "critical"
        },
		ENERGIZE = {
            "amount",
            "overpower",
            "powerType",
            "powerMaximum"
        },
		DRAIN = {
            "amount",
            "powerType",
            "extraAmount"
        },
		LEECH = {
            "amount",
            "powerType",
            "extraAmount"
        },
		INTERRUPT = {
            "extraSpellID",
            "extraSpellName",
            "extraSpellSchool"
        },
		DISPEL = {
            "extraSpellID",
            "extraSpellName",
            "extraSpellSchool",
            "auraType"
        },
		DISPEL_FAILED = {
            "extraSpellID",
            "extraSpellName",
            "extraSpellSchool"
        },
		STOLEN = {
            "extraSpellID",
            "extraSpellName",
            "extraSpellSchool",
            "auraType"
        },
		EXTRA_ATTACKS = {
            "amount"
        },
		AURA_APPLIED = {
            "auraType",
            "amount"
        },
		AURA_REMOVED = {
            "auraType",
            "amount"
        },
		AURA_APPLIED_DOSE = {
            "auraType",
            "amount"
        },
		AURA_REMOVED_DOSE = {
            "auraType",
            "amount"
        },
		AURA_REFRESH = {
            "auraType",
            "amount"
        },
		AURA_BROKEN = {
            "auraType"
        },
		AURA_BROKEN_SPELL = {
            "extraSpellID",
            "extraSpellName",
            "extraSpellSchool",
            "auraType"
        },
		CAST_START = {},
		CAST_SUCCESS = {},
		CAST_FAILED = {
            "failType"
        },
		INSTAKILL = {},
		DURABILITY_DAMAGE = {},
		DURABILITY_DAMAGE_ALL = {},
		CREATE = {},
		SUMMON = {},
		RESURRECT = {}
	}

    self.events = {}

    ----------------------------------------------------------------------------
    -- Frame
    ----------------------------------------------------------------------------

    self:Setup()

    ----------------------------------------------------------------------------
    -- Modules
    ----------------------------------------------------------------------------

    self.modules = {}
    self.resets = {}

    Damage:Enable()
    DamageBreakdown:Enable()
    Healing:Enable()
    HealingBreakdown:Enable()

    CM:OnUpdate({"ENABLE"}, function()
    end)

    self:SetModule(self:GetModule())

    ----------------------------------------------------------------------------
    -- Initialization
    ----------------------------------------------------------------------------

    CM:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function()
        CM:Parse(CombatLogGetCurrentEventInfo())
    end)

    CM:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        CM:Start()
    end)
    CM:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        CM:Stop()
    end)
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

function CM:Filters()

    return {
        IsMine = function(flags)
            return (bit.band(flags or 0, self.BITMASK_MINE) ~= 0)
        end,
        InGroup = function(flags)
            return (bit.band(flags or 0, self.BITMASK_GROUP) ~= 0)
        end,
        IsPet = function(flags)
            return (bit.band(flags or 0, self.BITMASK_PETS) ~= 0)
        end,
        IsFriendly = function(flags)
            return (bit.band(flags or 0, self.BITMASK_FRIENDLY) ~= 0)
        end,
        IsNeutral = function(flags)
            return (bit.band(flags or 0, self.BITMASK_NEUTRAL) ~= 0)
        end,
        IsHostile = function(flags)
            return (bit.band(flags or 0, self.BITMASK_HOSTILE) ~= 0)
        end,
        IsPlayer = function(flags)
            return (bit.band(flags or 0, self.BITMASK_PLAYER) == self.BITMASK_PLAYER)
        end,
        IsNPC = function(flags)
            return (bit.band(flags or 0, self.BITMASK_NPC) ~= 0)
        end,
        IsNone = function(flags)
            return (bit.band(flags or 0, self.BITMASK_NONE) ~= 0)
        end
    }

end

function CM:Player()
    local _, class, _, race, _, name = GetPlayerInfoByGUID(UnitGUID("player"))

    return name, class, race
end

function CM:Format(number)

    if number > 999999999 then
        return ("%02.3fB"):format(number / 1000000000)
    end

    if number > 999999 then
        return ("%02.2fM"):format(number / 1000000)
    end

    if number > 9999 then
        return ("%02.1fK"):format(number / 1000)
    end

    return math.floor(number)
end

function CM:Round(number, precision)
    precision = precision <= 0 and precision or -precision
    precision = math.pow(10, precision)
    number = number + (precision / 2)

    return math.floor(number / precision) * precision
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function CM:OnEvent(event, callback)
    self.events[event] = self.events[event] or {}

    table.insert(self.events[event], callback)
end

function CM:OnEvents(events, callback)

    for _, event in ipairs(events) do
        self:OnEvent(event, callback)
    end

end

function CM:HasEvent(event)
    return self.events[event]
end

function CM:Dispatch(event)

    for _, callback in ipairs(event.callbacks) do
        callback(event)
    end

end

--------------------------------------------------------------------------------
-- Parser
--------------------------------------------------------------------------------

function CM:Parse(timestamp, token, ...)

    if CM:HasEvent(token) then
        local event = {}
        event.callbacks = self.events[token]
        event.timestamp = timestamp
        event.token = self.ALIASES[token] or token

        local arguments = {
            "hideCaster",
            "sourceGUID",
            "sourceName",
            "sourceFlags",
            "sourceRaidFlags",
            "destinationGUID",
            "destinationName",
            "destinationFlags",
            "destinationRaidFlags"
        }

        for prefix in pairs(self.PREFIXES) do
            local length = string.len(prefix)

            if prefix == string.sub(event.token, 1, length) then
                local suffix = string.sub(event.token, length + 2)

                if self.SUFFIXES[suffix] then
                    event.prefix = prefix
                    event.suffix = suffix

                    tAppendAll(arguments, self.PREFIXES[prefix])
                    tAppendAll(arguments, self.SUFFIXES[suffix])
                end

            end

        end

        for index, argument in ipairs(arguments) do
            event[argument] = select(index, ...)
        end

        event = Mixin(event, self:Filters())

        if event.token == "SWING_DAMAGE" or event.token == "SWING_MISSED" then
            event.spellID = 6603
            event.spellName = GetSpellInfo(6603)
            event.spellSchool = 0x01
        end

        if event.missType == "ABSORB" and event.amount then
            event.absorbed = event.amount
            event.amount = 0
        elseif event.missType == "BLOCK" and event.amount then
            event.blocked = event.amount
            event.amount = 0
        elseif event.missType == "RESIST" and event.amount then
            event.resisted = event.amount
            event.amount = 0
        elseif event.missType and not event.amount then
            event.amount = 0
        end

        if not event.sourceName then
            CM:Print("Source GUID: " .. event.sourceGUID)
            CM:Print("Destination: " .. event.destinationName)
            return
        end

        self:Dispatch(event)

        if self:HasUpdate(self:GetModule(), event.token) then
            self:Update(event.token, self:GetUpdate(self:GetModule(), event.token))
        end

    end

end

function CM:GetOwner(GUID)

    if GUID == UnitGUID("pet") then
        local ownerGUID = UnitGUID("player")
        local ownerName = UnitName("player")
        local ownerFlags = 0x00000511

        return ownerGUID, ownerName, ownerFlags
    end

    if IsInRaid() then

        for i = 1, GetNumGroupMembers() do

            if GUID == UnitGUID("raidpet" .. i) then
                local ownerGUID = UnitGUID("raid" .. i)
                local ownerName = UnitName("raid" .. i)
                local ownerFlags = 0x00000417
            end

        end

    elseif IsInGroup() then

        for i = 1, GetNumGroupMembers() - 1 do

            if GUID == UnitGUID("partypet" .. i) then
                local ownerGUID = UnitGUID("party" .. i)
                local ownerName = UnitName("party" .. i)
                local ownerFlags = 0x00000417
            end

        end

    end

end

function CM:Start()

    if not self.started then
        self.started = time()
    end

end

function CM:Stop()

    if not self:InCombat() then

        if self.timer then
            self:CancelTimer(self.timer)
            self.timer = nil
        end

        self.started = nil
        self:Reset()
    else
        self.timer = self:ScheduleTimer("Stop", 1)
    end

end

function CM:OnReset(callback)
    self.resets = self.resets or {}

    table.insert(self.resets, callback)
end

function CM:Reset()

    for _, callback in ipairs(self.resets) do
        callback()
    end

end

function CM:Started()
    return self.started
end

function CM:InCombat()
    local state = InCombatLockdown()

    if IsInRaid() then

        for i = 1, GetNumGroupMembers() do
            state = state or UnitAffectingCombat("raid" .. i)
        end

    elseif IsInGroup() then

        for i = 1, GetNumGroupMembers() do
            state = state or UnitAffectingCombat("party" .. i)
        end

    end

    return state
end

--------------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------------

function CM:Setup()
    self.Frame = CreateFrame("GameTooltip", "CMContainer", UIParent, "SharedTooltipTemplate")
    self.Frame:SetOwner(UIParent, "ANCHOR_NONE")
    self.Frame:SetFrameStrata("LOW")
end

function CM:Header(header, additional)
    self.Frame:ClearLines()
    self.Frame:AddDoubleLine(header, additional)
end

function CM:Line(content, red, green, blue)
    self.Frame:AddLine(content, red or 1, green or 1, blue or 1)
end

function CM:DoubleLine(content, additional, red, green, blue, additionalRed, additionalGreen, additionalBlue)
    self.Frame:AddDoubleLine(content, additional, red or 1, green or 1, blue or 1, additionalRed or 1, additionalGreen or 1, additionalBlue or 1)
end

function CM:Update(event, callback)

    if event ~= "ENABLE" and not self:Started() then
        return
    end

    self.Frame:SetOwner(UIParent, "ANCHOR_NONE")
    self.Frame:ClearLines()

    if callback then
        callback()
    end

    self.Frame:Show()
    self.Frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 10)
end

function CM:OnUpdate(events, callback)
    local module = {}

    for _, event in ipairs(events) do
        module[event] = callback
    end

    module["ENABLE"] = callback

    table.insert(self.modules, module)
end

function CM:HasUpdate(module, event)

    if self.modules[module] and self.modules[module][event] then
        return true
    else
        return false
    end

end

function CM:GetUpdate(module, event)

    if self:HasUpdate(module, event) then
        return self.modules[module][event]
    end

end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------

function CM:SetModule(module)

    if self.modules[module] then
        self.database.profile["module"] = module
        self:Update("ENABLE", self:GetUpdate(module, "ENABLE"))
    end

end

function CM:GetModule()
    return self.database.profile["module"] or 1
end

function CM:FirstModule()
    self:SetModule(1)
end

function CM:LastModule()
    self:SetModule(#self.modules)
end

function CM:NextModule()
    local module = self:GetModule()
    local modules = #self.modules

    if modules > 0 then

        if module < modules then
            self:SetModule(module + 1)
        elseif module == modules then
            self:FirstModule()
        end

    end

end

function CM:PreviousModule()
    local module = self:GetModule()
    local modules = #self.modules

    if modules > 0 then

        if module == 1 then
            self:LastModule()
        else
            self:SetModule(module - 1)
        end

    end

end

--------------------------------------------------------------------------------
-- Damage
--------------------------------------------------------------------------------

function Damage:Enable()
    self:Reset()

    self.events = {
        "DAMAGE_SHIELD",
        "DAMAGE_SPLIT",
        "RANGE_DAMAGE",
        "SPELL_BUILDING_DAMAGE",
        "SPELL_DAMAGE",
        "SPELL_PERIODIC_DAMAGE",
        "SWING_DAMAGE",
        "DAMAGE_SHIELD_MISSED",
        "RANGE_MISSED",
        "SPELL_BUILDING_MISSED",
        "SPELL_MISSED",
        "SPELL_PERIODIC_MISSED",
        "SWING_MISSED"
    }

    CM:OnEvents(self.events, function(event)
        self:Parse(event)
    end)
    CM:OnUpdate(self.events, function()
        self:Update()
    end)
    CM:OnReset(function()
        self:Reset()
    end)
end

function Damage:Parse(event)

    if event.IsPet(event.sourceFlags) then
        event.sourceGUID, event.sourceName, event.sourceFlags = CM:GetOwner(event.sourceGUID)
    end

    if not event.sourceName then
        return
    end

    if event.IsMine(event.sourceFlags) or event.InGroup(event.sourceFlags) then

        if not event.amount then
            CM:Print(event.token)
            return
        end

        self.data = self.data or {}
        self.data[event.sourceName] = self.data[event.sourceName] or {}
        self.data[event.sourceName].damage = self.data[event.sourceName].damage or 0
        self.data[event.sourceName].damage = self.data[event.sourceName].damage + event.amount
        self.data[event.sourceName].color = self.data[event.sourceName].color or {}

        if event.IsPlayer(event.sourceFlags) then
            local _, class = GetPlayerInfoByGUID(event.sourceGUID)

            self.data[event.sourceName].color.r,
            self.data[event.sourceName].color.g,
            self.data[event.sourceName].color.b = GetClassColor(class)
        else
            self.data[event.sourceName].color.r = 1
            self.data[event.sourceName].color.g = 1
            self.data[event.sourceName].color.b = 1
        end

    end

end

function Damage:Update()
    CM:Header("Damage")

    if self.data then
        local elapsed = math.max(time() - (CM:Started() or time()), 1)

        local sorted = {}

        for source in pairs(self.data) do
            table.insert(sorted, source)
        end

        table.sort(sorted, function(a, b)
            return self.data[a].damage > self.data[b].damage
        end)

        for i = 1, #sorted do
            local damage = self.data[sorted[i]].damage
            local color = self.data[sorted[i]].color

            damage = string.format("%s (%s)", CM:Format(damage), CM:Format(damage / elapsed))

            CM:DoubleLine(sorted[i], damage, color.r, color.g, color.b, 1, 1, 1)
        end

    end

end

function Damage:Reset()
    self.data = {}

    local playerName, playerClass = CM:Player()

    self.data[playerName] = {}
    self.data[playerName].damage = 0
    self.data[playerName].color = {}
    self.data[playerName].color.r,
    self.data[playerName].color.g,
    self.data[playerName].color.b = GetClassColor(playerClass)
end

--------------------------------------------------------------------------------
-- DamageBreakdown
--------------------------------------------------------------------------------

function DamageBreakdown:Enable()
    self:Reset()

    self.events = {
        "DAMAGE_SHIELD",
        "DAMAGE_SPLIT",
        "RANGE_DAMAGE",
        "SPELL_BUILDING_DAMAGE",
        "SPELL_DAMAGE",
        "SPELL_PERIODIC_DAMAGE",
        "SWING_DAMAGE",
        "DAMAGE_SHIELD_MISSED",
        "RANGE_MISSED",
        "SPELL_BUILDING_MISSED",
        "SPELL_MISSED",
        "SPELL_PERIODIC_MISSED",
        "SWING_MISSED"
    }

    CM:OnEvents(self.events, function(event)
        self:Parse(event)
    end)
    CM:OnUpdate(self.events, function()
        self:Update()
    end)
    CM:OnReset(function()
        self:Reset()
    end)
end

function DamageBreakdown:Parse(event)

    if event.IsPet(event.sourceFlags) then
        event.sourceGUID, event.sourceName, event.sourceFlags = CM:GetOwner(event.sourceGUID)
    end

    if event.IsMine(event.sourceFlags) then
        self.data = self.data or {}
        self.data[event.sourceName] = self.data[event.sourceName] or {}
        self.data[event.sourceName].damage = self.data[event.sourceName].damage or 0
        self.data[event.sourceName].damage = self.data[event.sourceName].damage + event.amount
        self.data[event.sourceName].spells = self.data[event.sourceName].spells or {}
        self.data[event.sourceName].spells[event.spellName] = self.data[event.sourceName].spells[event.spellName] or 0
        self.data[event.sourceName].spells[event.spellName] = self.data[event.sourceName].spells[event.spellName] + event.amount
        self.data[event.sourceName].color = self.data[event.sourceName].color or {}

        if event.IsPlayer(event.sourceFlags) then
            local _, class = GetPlayerInfoByGUID(event.sourceGUID)

            self.data[event.sourceName].color.r,
            self.data[event.sourceName].color.g,
            self.data[event.sourceName].color.b = GetClassColor(class)
        else
            self.data[event.sourceName].color.r = 1
            self.data[event.sourceName].color.g = 1
            self.data[event.sourceName].color.b = 1
        end

    end

end

function DamageBreakdown:Update()
    CM:Header("Damage Breakdown")

    if self.data then

        for source, data in pairs(self.data) do
            local sorted = {}

            CM:Header("Damage Breakdown", CM:Format(data.damage))

            if data.spells then

                for spell, damage in pairs(data.spells) do
                    table.insert(sorted, spell)
                end

                table.sort(sorted, function(a, b)
                    return data.spells[a] > data.spells[b]
                end)

                for i = 1, #sorted do
                    local spell = sorted[i]
                    local damage = data.spells[spell]

                    damage = string.format("%s (%s%%)", CM:Format(damage), CM:Round((damage / data.damage) * 100, 1))

                    CM:DoubleLine(spell, damage)
                end

            else
                CM:DoubleLine("None", "0 (0%)")
            end

        end

    end

end

function DamageBreakdown:Reset()
    self.data = {}

    local playerName = CM:Player()

    self.data[playerName] = {}
    self.data[playerName].damage = 0
end

--------------------------------------------------------------------------------
-- Healing
--------------------------------------------------------------------------------

function Healing:Enable()
    self:Reset()

    self.events = {
        "SPELL_HEAL",
        "SPELL_PERIODIC_HEAL"
    }

    CM:OnEvents(self.events, function(event)
        self:Parse(event)
    end)
    CM:OnUpdate(self.events, function()
        self:Update()
    end)
    CM:OnReset(function()
        self:Reset()
    end)
end

function Healing:Parse(event)

    if event.IsPet(event.sourceFlags) then
        event.sourceGUID, event.sourceName, event.sourceFlags = CM:GetOwner(event.sourceGUID)
    end

    if event.IsMine(event.sourceFlags) or event.InGroup(event.sourceFlags) then
        self.data = self.data or {}
        self.data[event.sourceName] = self.data[event.sourceName] or {}
        self.data[event.sourceName].healing = self.data[event.sourceName].healing or 0
        self.data[event.sourceName].healing = self.data[event.sourceName].healing + event.amount
        self.data[event.sourceName].color = self.data[event.sourceName].color or {}

        if event.IsPlayer(event.sourceFlags) then
            local _, class = GetPlayerInfoByGUID(event.sourceGUID)

            self.data[event.sourceName].color.r,
            self.data[event.sourceName].color.g,
            self.data[event.sourceName].color.b = GetClassColor(class)
        else
            self.data[event.sourceName].color.r = 1
            self.data[event.sourceName].color.g = 1
            self.data[event.sourceName].color.b = 1
        end

    end

end

function Healing:Update()
    CM:Header("Healing")

    if self.data then
        local elapsed = math.max(time() - (CM:Started() or time()), 1)
        local sorted = {}

        for source in pairs(self.data) do
            table.insert(sorted, source)
        end

        table.sort(sorted, function(a, b)
            return self.data[a].healing > self.data[b].healing
        end)

        for i = 1, #sorted do
            local healing = self.data[sorted[i]].healing
            local color = self.data[sorted[i]].color

            healing = string.format("%s (%s)", CM:Format(healing), CM:Format(healing / elapsed))

            CM:DoubleLine(sorted[i], healing, color.r, color.g, color.b, 1, 1, 1)
        end

    end

end

function Healing:Reset()
    self.data = {}

    local playerName, playerClass = CM:Player()

    self.data[playerName] = {}
    self.data[playerName].healing = 0
    self.data[playerName].color = {}
    self.data[playerName].color.r,
    self.data[playerName].color.g,
    self.data[playerName].color.b = GetClassColor(playerClass)
end

--------------------------------------------------------------------------------
-- DamageBreakdown
--------------------------------------------------------------------------------

function HealingBreakdown:Enable()
    self:Reset()

    self.events = {
        "SPELL_HEAL",
        "SPELL_PERIODIC_HEAL"
    }

    CM:OnEvents(self.events, function(event)
        self:Parse(event)
    end)
    CM:OnUpdate(self.events, function()
        self:Update()
    end)
    CM:OnReset(function()
        self:Reset()
    end)
end

function HealingBreakdown:Parse(event)

    if event.IsPet(event.sourceFlags) then
        event.sourceGUID, event.sourceName, event.sourceFlags = CM:GetOwner(event.sourceGUID)
    end

    if event.IsMine(event.sourceFlags) then
        self.data = self.data or {}
        self.data[event.sourceName] = self.data[event.sourceName] or {}
        self.data[event.sourceName].healing = self.data[event.sourceName].healing or 0
        self.data[event.sourceName].healing = self.data[event.sourceName].healing + event.amount
        self.data[event.sourceName].spells = self.data[event.sourceName].spells or {}
        self.data[event.sourceName].spells[event.spellName] = self.data[event.sourceName].spells[event.spellName] or 0
        self.data[event.sourceName].spells[event.spellName] = self.data[event.sourceName].spells[event.spellName] + event.amount
        self.data[event.sourceName].color = self.data[event.sourceName].color or {}

        if event.IsPlayer(event.sourceFlags) then
            local _, class = GetPlayerInfoByGUID(event.sourceGUID)

            self.data[event.sourceName].color.r,
            self.data[event.sourceName].color.g,
            self.data[event.sourceName].color.b = GetClassColor(class)
        else
            self.data[event.sourceName].color.r = 1
            self.data[event.sourceName].color.g = 1
            self.data[event.sourceName].color.b = 1
        end

    end

end

function HealingBreakdown:Update()
    CM:Header("Healing Breakdown")

    if self.data then

        for source, data in pairs(self.data) do
            local sorted = {}

            CM:Header("Healing Breakdown", CM:Format(data.healing))

            if data.spells then

                for spell, healing in pairs(data.spells) do
                    table.insert(sorted, spell)
                end

                table.sort(sorted, function(a, b)
                    return data.spells[a] > data.spells[b]
                end)

                for i = 1, #sorted do
                    local spell = sorted[i]
                    local healing = data.spells[spell]

                    healing = string.format("%s (%s%%)", CM:Format(healing), CM:Round((healing / data.healing) * 100, 1))

                    CM:DoubleLine(spell, healing)
                end

            else
                CM:DoubleLine("None", "0 (0%)")
            end

        end

    end

end

function HealingBreakdown:Reset()
    self.data = {}

    local playerName = CM:Player()

    self.data[playerName] = {}
    self.data[playerName].healing = 0
end
