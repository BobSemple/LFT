local LFT = CreateFrame("Frame")
local me = UnitName('player')
local addonVer = '0.0.1.1'
local showedUpdateNotification = false

local LFTTypeDropDown = CreateFrame('Frame', 'LFTTypeDropDown', UIParent, 'UIDropDownMenuTemplate')

LFT.class = ''
LFT.channel = 'LFT'
LFT.channelIndex = 0
LFT.level = UnitLevel('player')
LFT.findingGroup = false
LFT:RegisterEvent("ADDON_LOADED")
LFT:RegisterEvent("PLAYER_ENTERING_WORLD")
LFT:RegisterEvent("RAID_TARGET_UPDATE")
LFT:RegisterEvent("PLAYER_LEVEL_UP")
LFT.availableDungeons = {}
LFT.group = {}
LFT.oneGroupFull = false
LFT.groupFullCode = ''
LFT.acceptNextInvite = false
LFT.onlyAcceptFrom = ''
LFT.queueStartTime = 0
LFT.types = {
    [1] = 'Suggested Dungeons',
    [2] = 'Random Dungeon',
    [3] = 'All Available Dungeons'
}
LFT.maxDungeonsList = 11
LFT.minimapFrames = {}
LFT.myRandomTime = 0
LFT.random_min = 0
LFT.random_max = 24

LFT.RESET_TIME = 0
LFT.TANK_TIME = 2
LFT.HEALER_TIME = 5 -- 5 .. 29
LFT.DAMAGE_TIME = 5 -- 5 .. 29
LFT.TIME_MARGIN = 30

LFT.foundGroup = {}
LFT.inGroup = false
LFT.isLeader = false
LFT.LFMGroup = {}
LFT.LFMDungeonCode = ''

local COLOR_RED = '|cffff222a'
local COLOR_ORANGE = '|cffff8000'
local COLOR_GREEN = '|cff1fba1f'
local COLOR_HUNTER = '|cffabd473'
local COLOR_YELLOW = '|cffffff00'
local COLOR_WHITE = '|cffffffff'
local COLOR_DISABLED = '|cff888888'

local LFTChannelJoinDelay = CreateFrame("Frame")
LFTChannelJoinDelay:Hide()

LFTChannelJoinDelay:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFTChannelJoinDelay:SetScript("OnHide", function()
    LFT.checkLFTChannel()
end)

LFTChannelJoinDelay:SetScript("OnUpdate", function()
    local plus = 3 --seconds
    local gt = GetTime() * 1000 --22.123 -> 22123
    local st = (this.startTime + plus) * 1000 -- (22.123 + 0.1) * 1000 =  22.223 * 1000 = 22223
    if gt >= st then
        LFTChannelJoinDelay:Hide()
    end
end)

local LFTQueue = CreateFrame("Frame")
LFTQueue:Hide()

local LFTInvite = CreateFrame("Frame")
LFTInvite:Hide()
LFTInvite:SetScript("OnShow", function()
    this.startTime = GetTime()
    this.inviteIndex = 1
end)

LFTInvite:SetScript("OnUpdate", function()
    local plus = 1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()

        this.inviteIndex = this.inviteIndex + 1

        if this.inviteIndex == 2 then
            InviteByName(LFT.group[LFT.groupFullCode].healer)
        end
        if this.inviteIndex == 3 then
            InviteByName(LFT.group[LFT.groupFullCode].damage1)
            LFTInvite:Hide() --dev
        end
        --        if this.inviteIndex == 4 then
        --            InviteByName(LFT.group[LFT.groupFullCode].damage2)
        --        end
        --        if this.inviteIndex == 5 then
        --            InviteByName(LFT.group[LFT.groupFullCode].damage3)
        --            LFTInvite:Hide()
        --        end
    end
end)

local LFTRoleCheck = CreateFrame("Frame")
LFTRoleCheck:Hide()

LFTRoleCheck:SetScript("OnShow", function()
    this.startTime = GetTime()
    --    lfdebug('timer started, you have 25 seconds')
end)

LFTRoleCheck:SetScript("OnHide", function()
end)

LFTRoleCheck:SetScript("OnUpdate", function()
    local plus = 25 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        declineRole()
        LFTRoleCheck:Hide()
    end
end)

local LFTWhoCounter = CreateFrame("Frame")
LFTWhoCounter:Hide()
LFTWhoCounter.people = 0
LFTWhoCounter.listening = false
LFTWhoCounter:SetScript("OnShow", function()
    this.startTime = GetTime()
    LFTWhoCounter.people = 0
    LFTWhoCounter.listening = true
end)

LFTWhoCounter:SetScript("OnHide", function()
    lfprint('Found ' .. LFTWhoCounter.people .. ' online using LFT addon.')
    LFTWhoCounter.listening = false
end)

LFTWhoCounter:SetScript("OnUpdate", function()
    local plus = 5 --seconds
    local gt = GetTime() * 1000 --22.123 -> 22123
    local st = (this.startTime + plus) * 1000 -- (22.123 + 0.1) * 1000 =  22.223 * 1000 = 22223
    if gt >= st then
        LFTWhoCounter:Hide()
    end
end)



local LFTComms = CreateFrame("Frame")
LFTComms:Hide()
LFTComms:RegisterEvent("CHAT_MSG_CHANNEL")
LFTComms:RegisterEvent("CHAT_MSG_WHISPER")
LFTComms:RegisterEvent("PARTY_INVITE_REQUEST")
LFTComms:RegisterEvent("CHAT_MSG_ADDON")

LFTComms:SetScript("OnEvent", function()
    if event then
        if event == 'CHAT_MSG_ADDON' and arg1 == 'LFT' then
            lfdebug(arg4 .. ' says : ' .. arg2)
            if string.sub(arg2, 1, 11) == 'LFTVersion:' and arg4 ~= me then
                if not showedUpdateNotification then
                    local verEx = string.split(arg2, ':')
                    if LFT.ver(verEx[2]) > LFT.ver(addonVer) then
                        lfprint(COLOR_HUNTER .. 'Looking For Turtles ' .. COLOR_WHITE .. ' - new version available ' ..
                                COLOR_GREEN .. 'v' .. verEx[2] .. COLOR_WHITE .. ' (current version ' ..
                                COLOR_ORANGE .. 'v' .. addonVer .. COLOR_WHITE .. ')')
                        lfprint('Update yours at ' .. COLOR_HUNTER .. 'https://github.com/CosminPOP/LFT')
                        showedUpdateNotification = true
                    end
                end
            end
            -- fake fill minimap frames
            if string.sub(arg2, 1, 11) == 'leaveQueue:' and arg4 ~= me then
                leaveQueue()
            end
            if string.sub(arg2, 1, 8) == 'minimap:' then
                if not LFT.isLeader then
                    local miniEx = string.split(arg2, ':')
                    local code = miniEx[2]
                    local tank = tonumber(miniEx[3])
                    local healer = tonumber(miniEx[4])
                    local damage = tonumber(miniEx[5])
                    LFT.group[code] = {
                        tank = '',
                        healer = '',
                        damage1 = '',
                        damage2 = '',
                        damage3 = ''
                    }
                    if tank == 1 then LFT.group[code].tank = 'DummyTank' end
                    if healer == 1 then LFT.group[code].healer = 'DummyHealer' end
                    if damage > 0 then LFT.group[code].damage1 = 'DummyDamage1' end
                    if damage > 1 then LFT.group[code].damage2 = 'DummyDamage2' end
                    if damage > 2 then LFT.group[code].damage3 = 'DummyDamage3' end
                end
            end
            if string.sub(arg2, 1, 14) == 'LFMPartyReady:' then

                --check if sender = party leader
                if UnitName('party' .. GetPartyLeaderIndex()) == arg4 or LFT.isLeader then

                    local queueEx = string.split(arg2, ':')
                    local mCode = queueEx[2]
                    LFT.groupFullCode = mCode
                    --untick everything
                    for i, frame in LFT.availableDungeons do
                        getglobal('Dungeon_' .. LFT.groupFullCode):SetChecked(false)
                    end
                    LFT.findingGroup = false
                    LFT.findingMore = false
                    local background = ''
                    local dungeonName = 'unknown'
                    for d, data in next, LFT.dungeons do
                        if data.code == mCode then
                            background = data.background
                            dungeonName = d
                        end
                    end
                    getglobal('LFTGroupReadyBackground'):SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
                    getglobal('LFTGroupReadyRole'):SetTexture('Interface\\addons\\LFT\\images\\' .. LFT_ROLE .. '2')
                    getglobal('LFTGroupReadyMyRole'):SetText(LFT.ucFirst(LFT_ROLE))
                    getglobal('LFTGroupReadyDungeonName'):SetText(dungeonName)
                    getglobal('LFTGroupReady'):Show()

                    PlaySound("ReadyCheck")
                    LFT.fixMainButton()
                    getglobal('LFTMain'):Hide()
                end
                LFT.findingMore = false
            end
            if string.sub(arg2, 1, 10) == 'weInQueue:' then
                local queueEx = string.split(arg2, ':')
                LFT.weInQueue(queueEx[2])
            end
            if string.sub(arg2, 1, 10) == 'roleCheck:' then
                lfprint('A role check has been initiated. Your group will be queued when all members have selected a role.')
                UIErrorsFrame:AddMessage("|cff69ccf0[LFT] |cffffff00A role check has been initiated. Your group will be queued when all members have selected a role.")

                local argEx = string.split(arg2, ':')
                local mCode = argEx[2]
                LFT.LFMDungeonCode = mCode
                LFT.resetGroup()

                if LFT.isLeader then
                    if LFT_ROLE == 'tank' then LFT.LFMGroup.tank = me end
                    if LFT_ROLE == 'healer' then LFT.LFMGroup.healer = me end
                    if LFT_ROLE == 'damage' then LFT.LFMGroup.damage1 = me end
                else
                    getglobal('LFTRoleCheckQForText'):SetText(COLOR_WHITE .. "Queued for " .. COLOR_YELLOW .. LFT.dungeonNameFromCode(mCode))
                    getglobal('LFTRoleCheck'):Show()
                    LFTRoleCheck:Show()
                end
            end

            if string.sub(arg2, 1, 11) == 'acceptRole:' then
                local roleEx = string.split(arg2, ':')

                if roleEx[2] == 'tank' then LFT.LFMGroup.tank = arg4 end
                if roleEx[2] == 'healer' then LFT.LFMGroup.healer = arg4 end
                if roleEx[2] == 'damage' then
                    if LFT.LFMGroup.damage1 == '' then
                        LFT.LFMGroup.damage1 = arg4
                    elseif LFT.LFMGroup.damage2 == '' then
                        LFT.LFMGroup.damage2 = arg4
                    elseif LFT.LFMGroup.damage3 == '' then
                        LFT.LFMGroup.damage3 = arg4
                    end
                end
                LFT.checkLFMgroup()
            end
            if string.sub(arg2, 1, 12) == 'declineRole:' then
                LFT.checkLFMgroup(arg4)
            end
        end
        if event == 'PARTY_INVITE_REQUEST' and LFT.acceptNextInvite then
            if arg1 == LFT.onlyAcceptFrom then
                LFT.AcceptGroupInvite()
                LFT.acceptNextInvite = false
            else
                LFT.DeclineGroupInvite()
            end
        end
        if event == 'CHAT_MSG_WHISPER' and string.find(arg1, '[LFT]', 1, true) and --for lfm
                string.find(arg1, ' (LFM)', 1, true) then
            LFT.onlyAcceptFrom = arg2
            LFT.acceptNextInvite = true
            --todo message the channel so everyone will remove me from their virtual lists
        end
        if event == 'CHAT_MSG_WHISPER' and string.find(arg1, '[LFT]', 1, true) and --for lfg
                string.find(arg1, 'party ready', 1, true) then
            local mEx = string.split(arg1, ' ')

            LFT.onlyAcceptFrom = arg2
            LFT.acceptNextInvite = true

            local background = ''
            local dungeonName = 'unknown'
            for d, data in next, LFT.dungeons do
                if data.code == mEx[2] then
                    background = data.background
                    dungeonName = d
                end
            end
            getglobal('LFTGroupReadyBackground'):SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
            getglobal('LFTGroupReadyRole'):SetTexture('Interface\\addons\\LFT\\images\\' .. LFT_ROLE .. '2')
            getglobal('LFTGroupReadyMyRole'):SetText(LFT.ucFirst(LFT_ROLE))
            getglobal('LFTGroupReadyDungeonName'):SetText(dungeonName)
            getglobal('LFTGroupReady'):Show()

            PlaySound("ReadyCheck")

            LFT.findingGroup = false
            LFT.findingMore = false
            getglobal('LFTMain'):Hide()

            LFT.fixMainButton()
        end

        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFT.channelIndex and arg2 ~= me then
            if string.sub(arg1, 1, 7) == 'whoLFT:' then
                SendChatMessage('meLFT:' .. addonVer, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
            end
            if string.sub(arg1, 1, 6) == 'meLFT:' then
                if LFTWhoCounter.listening then
                    LFTWhoCounter.people = LFTWhoCounter.people + 1
                end
            end
        end
        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFT.channelIndex and not LFT.oneGroupFull and (LFT.findingGroup or LFT.findingMore) then -- and arg2 ~= me then

            if string.sub(arg1, 1, 6) == 'found:' then
                local foundEx = string.split(arg1, ':')
                local mRole = foundEx[2]
                local mDungeon = foundEx[3]

                if LFT_ROLE == mRole and not LFT.foundGroup[mDungeon] then
                    SendChatMessage('goingWith:' .. arg2 .. ':' .. mDungeon, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                    LFT.foundGroup[mDungeon] = true
                end
            end

            if string.sub(arg1, 1, 10) == 'goingWith:' and LFT_ROLE == 'tank' then
                local withEx = string.split(arg1, ':')
                local leader = withEx[2]
                local mDungeon = withEx[3]

                if leader ~= me then
                    LFT.remHealerOrDamage(mDungeon, arg2)
                end
            end

            if string.sub(arg1, 1, 4) == 'LFG:' then

                local spamSplit = string.split(arg1, ':')
                local mDungeonCode = spamSplit[2]
                local mRole = spamSplit[3] --other's role

                for dungeon, data in next, LFT.dungeons do
                    if data.queued and data.code == mDungeonCode then

                        -- LFM, leader found someone
                        if LFT.isLeader then
                            if LFT.isNeededInLFMGroup(mRole, arg2) then
                                LFT.inviteInLFMGroup(arg2)
                                --send minimap data to others
                                LFT.sendMinimapDataToParty(mDungeonCode)
                            end
                            return true
                        end


                        if LFT_ROLE == 'tank' then
                            LFT.group[mDungeonCode].tank = me

                            if mRole == 'healer' then LFT.addHealer(mDungeonCode, arg2) end
                            if mRole == 'damage' then LFT.addDamage(mDungeonCode, arg2) end
                        end

                        --pseudo fill group for tooltip display
                        if LFT_ROLE == 'healer' then
                            LFT.addHealer(mDungeonCode, me, true)

                            if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                                LFT.group[mDungeonCode].tank = arg2
                            end

                            if mRole == 'damage' then
                                LFT.addDamage(mDungeonCode, arg2, true)
                            end
                        end

                        if LFT_ROLE == 'damage' then
                            LFT.addDamage(mDungeonCode, me, true)
                            if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                                LFT.group[mDungeonCode].tank = arg2
                            end
                            if mRole == 'healer' and LFT.group[mDungeonCode].healer == '' then
                                LFT.group[mDungeonCode].healer = arg2
                            end
                        end
                    end
                end

                if LFT_ROLE == 'tank' then
                    local groupFull, code, healer, damage1, damage2, damage3 = LFT.checkGroupFull()

                    if groupFull then
                        LFT.groupFullCode = code

                        SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER", DEFAULT_CHAT_FRAME.editBox.languageID, healer);
                        SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER", DEFAULT_CHAT_FRAME.editBox.languageID, damage1);
                        --                    SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER",  DEFAULT_CHAT_FRAME.editBox.languageID, damage2);
                        --                    SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER",  DEFAULT_CHAT_FRAME.editBox.languageID, damage3);

                        --untick everything
                        for i, frame in LFT.availableDungeons do
                            getglobal('Dungeon_' .. code):SetChecked(false)
                        end

                        LFT.findingGroup = false
                        LFT.findingMore = false

                        local background = ''
                        local dungeonName = 'unknown'
                        for d, data in next, LFT.dungeons do
                            if data.code == code then
                                background = data.background
                                dungeonName = d
                            end
                        end
                        getglobal('LFTGroupReadyBackground'):SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
                        getglobal('LFTGroupReadyRole'):SetTexture('Interface\\addons\\LFT\\images\\' .. LFT_ROLE .. '2')
                        getglobal('LFTGroupReadyMyRole'):SetText(LFT.ucFirst(LFT_ROLE))
                        getglobal('LFTGroupReadyDungeonName'):SetText(dungeonName)
                        getglobal('LFTGroupReady'):Show()

                        PlaySound("ReadyCheck")

                        LFT.fixMainButton()
                        getglobal('LFTMain'):Hide()
                        LFTInvite:Show()
                    end
                end
            end
        end
    end
end)

function lfprint(a)
    if a == nil then
        DEFAULT_CHAT_FRAME:AddMessage(COLOR_HUNTER .. '[LFT]|cff0070de:' .. time() .. '|cffffffff attempt to print a nil value.')
        return false
    end
    DEFAULT_CHAT_FRAME:AddMessage(COLOR_HUNTER .. "[LFT] |cffffffff" .. a)
end

function lferror(a)
    DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[LFTError]|cff0070de:' .. time() .. '|cffffffff[' .. a .. ']')
end

function lfdebug(a)
    if me ~= 'Holystrike' and me ~= 'Cosmort' and
            me ~= 'Cosmin' and me ~= 'Kzktst' and
            me ~= 'Er' and me ~= 'Rake' and
            me ~= 'Kaizer' and me ~= 'Laciupacapra' and
            me ~= 'Pog' and me ~= 'Xerron' and
            me ~= 'Holystrike' and me ~= 'Xerrtwo' then
        return false
    end
    if type(a) == 'boolean' then
        if a then
            lfprint('|cff0070de[LFTDEBUG:' .. time() .. ']|cffffffff[true]')
        else
            lfprint('|cff0070de[LFTDEBUG:' .. time() .. ']|cffffffff[false]')
        end
        return true
    end
    lfprint('|cff0070de[LFTDEBUG:' .. time() .. ']|cffffffff[' .. a .. ']')
end

LFT:SetScript("OnEvent", function()
    if event then
        if event == "ADDON_LOADED" and arg1 == 'LFT' then
            LFT.init()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            LFT.level = UnitLevel('player')
            LFT.sendMyVersion()
        end
        if event == "RAID_TARGET_UPDATE" then
            LFT.isLeader = LFT.playerIsPartyLeader()
            LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0
            lfdebug('raid target update')
            if LFT.findingMore then
                if LFT.checkLFMGroupReady() then
                    SendAddonMessage('LFT', "LFMPartyReady:" .. LFT.LFMDungeonCode, "PARTY")
                else
                    --                    lfdebug('lfm party not ready yet')
                end
            else
                if LFT.findingGroup then
                    LFT.findingGroup = false
                end
                leaveQueue()
            end
            if not inGroup then
                leaveQueue()
            end
            if not LFT.isLeader then
                getglobal('LFTMain'):Hide()
            end
            LFT.fillAvailableDungeons()
        end
        if event == 'PLAYER_LEVEL_UP' then
            LFT.level = arg1
            LFT.fillAvailableDungeons()
        end
    end
end)

function LFT.init()

    local _, uClass = UnitClass('player')
    LFT.class = string.lower(uClass)

    if not LFT_TYPE then
        LFT_TYPE = 1
    end
    UIDropDownMenu_SetText(LFT.types[LFT_TYPE], getglobal('LFTTypeSelect'));
    getglobal('LFTDungeonsText'):SetText(LFT.types[LFT_TYPE])
    if not LFT_ROLE then
        LFT_ROLE = LFT.GetPossibleRoles()
    else
        LFT.GetPossibleRoles()
        LFTsetRole(LFT_ROLE)
    end


    LFT.channel = 'LFT'
    LFT.channelIndex = 0
    LFT.level = UnitLevel('player')
    LFT.findingGroup = false
    LFT.findingMore = false
    LFT:RegisterEvent("ADDON_LOADED")
    LFT.availableDungeons = {}
    LFT.group = {}
    LFT.oneGroupFull = false
    LFT.groupFullCode = ''
    LFT.acceptNextInvite = false
    LFT.minimapFrameIndex = 0

    LFT.isLeader = LFT.playerIsPartyLeader()
    LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0
    LFT.fixMainButton()

    LFT.fillAvailableDungeons()

    LFTChannelJoinDelay:Show()

    lfprint(COLOR_HUNTER .. 'Looking For Turtles v' .. addonVer .. COLOR_WHITE .. ' - LFG Addon for Turtle WoW loaded.')
end

LFTQueue:SetScript("OnShow", function()
    this.startTime = GetTime()
    this.lastTime = {
        tank = 0,
        damage = 0,
        heal = 0,
        reset = 0
    }
end)

LFTQueue:SetScript("OnHide", function()
    getglobal('LFT_MinimapEye'):SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking0')
end)

LFTQueue:SetScript("OnUpdate", function()
    local plus = 0.15 --seconds
    local gt = GetTime() * 1000 --22.123 -> 22123
    local st = (this.startTime + plus) * 1000 -- (22.123 + 0.1) * 1000 =  22.223 * 1000 = 22223
    if gt >= st and LFT.findingGroup then
        this.startTime = GetTime()

        local cSecond = tonumber(date("%S", time()))

        getglobal('LFTTitleTime'):SetText(cSecond)
        getglobal('LFTGroupStatusTimeInQueue'):SetText('Time in Queue: ' .. SecondsToTime(time() - LFT.queueStartTime))

        if (cSecond == LFT.RESET_TIME or cSecond == LFT.RESET_TIME + LFT.TIME_MARGIN) and this.lastTime.reset ~= time() then
            if not LFT.inGroup then -- dont reset group if we're LFM
                LFT.resetGroup()
                this.lastTime.reset = time()
            end
        end

        if (cSecond == LFT.TANK_TIME or cSecond == LFT.TANK_TIME + LFT.TIME_MARGIN) and LFT_ROLE == 'tank' and this.lastTime.tank ~= time() then
            if not LFT.inGroup then -- only start forming group if im not already grouped
                for dungeon, data in next, LFT.dungeons do
                    if data.queued then
                        LFT.group[data.code].tank = me
                    end
                end
                --new: but do send lfg message if im a tank, to be picked up by LFM party leader
                LFT.sendLFMessage()
                this.lastTime.tank = time()
            end
        end

        if (cSecond == LFT.HEALER_TIME + LFT.myRandomTime or cSecond == LFT.HEALER_TIME + LFT.TIME_MARGIN + LFT.myRandomTime) and LFT_ROLE == 'healer' and this.lastTime.heal ~= time() then
            if not LFT.inGroup then -- dont spam lfm if im already in a group, because leader will pick up new players
                LFT.sendLFMessage()
                this.lastTime.heal = time()
            end
        end

        if (cSecond == LFT.DAMAGE_TIME + LFT.myRandomTime or cSecond == LFT.DAMAGE_TIME + LFT.TIME_MARGIN + LFT.myRandomTime) and LFT_ROLE == 'damage' and this.lastTime.damage ~= time() then
            if not LFT.inGroup then -- dont spam lfm if im already in a group, because leader will pick up new players
                LFT.sendLFMessage()
                this.lastTime.damage = time()
            end
        end

        getglobal('LFT_MinimapEye'):SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking' .. LFT.minimapFrameIndex)

        if LFT.minimapFrameIndex < 28 then
            LFT.minimapFrameIndex = LFT.minimapFrameIndex + 1
        else
            LFT.minimapFrameIndex = 0
        end
    end
end)

function LFT.checkLFTChannel()

    local lastVal = 0
    local chanList = { GetChannelList() }

    for index, value in next, chanList do
        if value == LFT.channel then
            LFT.channelIndex = lastVal
            break
        end
        lastVal = value
    end

    if LFT.channelIndex == 0 then
        JoinChannelByName(LFT.channel)
        --        lfdebug('join LFT channel call')
    else
        --        lfdebug('in LFT channel')
    end
end

function LFT.GetPossibleRoles()
    lfdebug('possible roles ' .. LFT.class)
    local tankCheck = getglobal('RoleTank')
    local healerCheck = getglobal('RoleHealer')
    local damageCheck = getglobal('RoleDamage')

    --ready check window
    local readyCheckTank = getglobal('roleCheckTank')
    local readyCheckHealer = getglobal('roleCheckHealer')
    local readyCheckDamage = getglobal('roleCheckDamage')

    tankCheck:Disable()
    tankCheck:SetChecked(false)
    healerCheck:Disable()
    healerCheck:SetChecked(false)
    damageCheck:Disable()
    damageCheck:SetChecked(false)

    readyCheckTank:Disable()
    readyCheckTank:SetChecked(false)
    readyCheckHealer:Disable()
    readyCheckHealer:SetChecked(false)
    readyCheckDamage:Disable()
    readyCheckDamage:SetChecked(false)

    if LFT.class == 'warrior' then
        readyCheckTank:Enable();
        tankCheck:Enable();

        readyCheckTank:SetChecked(true)
        tankCheck:SetChecked(true)

        readyCheckDamage:Enable()
        damageCheck:Enable()

        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        return 'tank'
    end
    if LFT.class == 'paladin' or LFT.class == 'druid' or LFT.class == 'shaman' then
        readyCheckTank:Enable();
        tankCheck:Enable();
        readyCheckTank:SetChecked(false)
        tankCheck:SetChecked(false)

        readyCheckHealer:Enable()
        healerCheck:Enable()
        readyCheckHealer:SetChecked(true)
        healerCheck:SetChecked(true)

        readyCheckDamage:Enable()
        damageCheck:Enable()
        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        return 'healer'
    end
    if LFT.class == 'priest' then
        readyCheckHealer:Enable()
        healerCheck:Enable()
        readyCheckHealer:SetChecked(true)
        healerCheck:SetChecked(true)

        readyCheckDamage:Enable()
        damageCheck:Enable()
        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        return 'healer'
    end
    if LFT.class == 'warlock' or LFT.class == 'hunter' or LFT.class == 'mage' or LFT.class == 'rogue' then
        readyCheckDamage:Enable()
        damageCheck:Enable()
        readyCheckDamage:SetChecked(true)
        damageCheck:SetChecked(true)
        return 'damage'
    end
    return 'damage'
end

function LFT.getAvailableDungeons(level, type)
    if level == 0 then return {} end
    local dungeons = {}
    for dungeon, data in next, LFT.dungeons do
        if level >= data.minLevel and level <= data.maxLevel and type ~= 3 then
            dungeons[data.code] = true
            --            lfdebug('level ' .. level .. ' dungeon = true = ' .. data.code)
        end
        if level >= data.minLevel and type == 3 then --all available
            dungeons[data.code] = true
            --            lfdebug('level ' .. level .. ' dungeon = true = ' .. data.code)
        end
    end
    --    lfdebug('get avail dungeons size : ' .. level .. ' size : ' .. LFT.tableSize(dungeons))
    return dungeons
end

function LFT.fillAvailableDungeons(offset)
    if not offset then offset = 0 end

    --unqueue queued
    for dungeon, data in next, LFT.dungeons do
        LFT.dungeons[dungeon].canQueue = true
        if data.queued and (LFT.level < data.minLevel or LFT.level > data.maxLevel) then
            LFT.dungeons[dungeon].queued = false
        end
    end

    --hide all
    for i, frame in next, LFT.availableDungeons do
        getglobal("Dungeon_" .. frame.code):Hide()
    end

    -- if grouped fill only dungeons that can be joined by EVERYONE
    if LFT.inGroup then
        --        lfdebug('in group')
        local groupAvailableDungeons = {}
        local party = {
            [0] = {
                level = LFT.level,
                dungeons = LFT.getAvailableDungeons(LFT.level, LFT_TYPE)
            }
        }
        for i = 1, 4 do
            party[i] = {
                level = UnitLevel('party' .. i),
                dungeons = LFT.getAvailableDungeons(UnitLevel('party' .. i), LFT_TYPE)
            }
        end

        for dungeonCode in next, LFT.getAvailableDungeons(LFT.level, LFT_TYPE) do
            local canAdd = false
            for i = 1, 4 do
                for code in next, party[i].dungeons do
                    if dungeonCode == code then
                        canAdd = true
                    end
                end
            end
            if canAdd then
            else
                LFT.dungeons[LFT.dungeonNameFromCode(dungeonCode)].canQueue = canAdd
                --                lfdebug('d ' .. dungeonCode .. ' disabled')
            end
        end
    end



    local dungeonIndex = 0

    for dungeon, data in next, LFT.dungeons do
        if LFT.level >= data.minLevel and LFT.level <= data.maxLevel and LFT_TYPE ~= 3 then

            dungeonIndex = dungeonIndex + 1
            if dungeonIndex > offset and dungeonIndex <= offset + LFT.maxDungeonsList then
                if not LFT.availableDungeons[data.code] then
                    LFT.availableDungeons[data.code] = CreateFrame("CheckButton", "Dungeon_" .. data.code, getglobal("LFTMain"), "LFT_DungeonCheck")
                end

                LFT.availableDungeons[data.code]:Show()

                local color = COLOR_GREEN
                if LFT.level == data.minLevel or LFT.level == data.minLevel + 1 then color = COLOR_RED end
                if LFT.level == data.minLevel + 2 or LFT.level == data.minLevel + 3 then color = COLOR_ORANGE end
                if LFT.level == data.minLevel + 4 or LFT.level == data.maxLevel + 5 then color = COLOR_GREEN end

                if LFT.level > data.maxLevel then color = COLOR_GREEN end

                getglobal('Dungeon_' .. data.code):Enable()

                if not data.canQueue then
                    color = COLOR_DISABLED
                    data.queued = false
                    LFT.addOnEnterTooltip(getglobal('Dungeon_' .. data.code .. '_Button'), dungeon .. ' is unavailable',
                        'Members in your party do not meet ', 'minimum level requirement (' .. data.minLevel .. ').')
                    getglobal('Dungeon_' .. data.code):Disable()
                end

                getglobal('Dungeon_' .. data.code .. 'Text'):SetText(color .. dungeon)
                getglobal('Dungeon_' .. data.code .. 'Levels'):SetText(color .. '(' .. data.minLevel .. ' - ' .. data.maxLevel .. ')')
                getglobal('Dungeon_' .. data.code .. '_Button'):SetID(dungeonIndex)

                LFT.availableDungeons[data.code]:SetPoint("TOP", getglobal("LFTMain"), "TOP", -145, -165 - 20 * (dungeonIndex - offset))
                LFT.availableDungeons[data.code].code = data.code

                LFT.dungeons[dungeon].queued = data.queued
                getglobal('Dungeon_' .. data.code):SetChecked(data.queued)


                if LFT_TYPE == 2 and not LFT.inGroup then
                    LFT.dungeons[dungeon].queued = true
                    getglobal('Dungeon_' .. data.code):SetChecked(true)
                end
            end
        end

        if LFT.level >= data.minLevel and LFT_TYPE == 3 then --all available

            dungeonIndex = dungeonIndex + 1
            if dungeonIndex > offset and dungeonIndex <= offset + LFT.maxDungeonsList then
                if not LFT.availableDungeons[data.code] then
                    LFT.availableDungeons[data.code] = CreateFrame("CheckButton", "Dungeon_" .. data.code, getglobal("LFTMain"), "LFT_DungeonCheck")
                end

                LFT.availableDungeons[data.code]:Show()

                local color = COLOR_GREEN
                if LFT.level == data.minLevel or LFT.level == data.minLevel + 1 then color = COLOR_RED end
                if LFT.level == data.minLevel + 2 or LFT.level == data.minLevel + 3 then color = COLOR_ORANGE end
                if LFT.level == data.minLevel + 4 or LFT.level == data.maxLevel + 5 then color = COLOR_GREEN end

                if LFT.level > data.maxLevel then color = COLOR_GREEN end

                getglobal('Dungeon_' .. data.code .. 'Text'):SetText(color .. dungeon)
                getglobal('Dungeon_' .. data.code .. 'Levels'):SetText(color .. '(' .. data.minLevel .. ' - ' .. data.maxLevel .. ')')
                getglobal('Dungeon_' .. data.code .. '_Button'):SetID(dungeonIndex)

                LFT.availableDungeons[data.code]:SetPoint("TOP", getglobal("LFTMain"), "TOP", -145, -165 - 20 * (dungeonIndex - offset))
                LFT.availableDungeons[data.code].code = data.code

                --                LFT.dungeons[dungeon].queued = data.queued
                --                getglobal('Dungeon_' .. data.code):SetChecked(data.queued)
            end
        end
    end

    LFT.fixMainButton()

    FauxScrollFrame_Update(getglobal('DungeonListScrollFrame'), dungeonIndex, LFT.maxDungeonsList, 16)
end

function LFT.enableDungeonCheckbuttons()
    for i, frame in next, LFT.availableDungeons do
        getglobal("Dungeon_" .. frame.code):Enable()
    end
end

function LFT.disableDungeonCheckbuttons(except)
    for i, frame in next, LFT.availableDungeons do
        if except and except == frame.code then
            --dont disable
        else
            getglobal("Dungeon_" .. frame.code):Disable()
        end
    end
end

function LFT.resetGroup()
    --    lfdebug('resetGroup()')
    LFT.group = {};
    if not LFT.oneGroupFull then
        LFT.groupFullCode = ''
        LFT.oneGroupFull = false
    end
    LFT.acceptNextInvite = false
    LFT.onlyAcceptFrom = ''
    LFT.foundGroup = {}

    LFT.isLeader = LFT.playerIsPartyLeader()

    LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0


    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            local tank = ''
            if LFT_ROLE == 'tank' then tank = me end
            LFT.foundGroup[data.code] = false
            LFT.group[data.code] = {
                tank = tank,
                healer = '',
                damage1 = '',
                damage2 = '',
                damage3 = '',
            }
        end
    end
    LFT.myRandomTime = math.random(LFT.random_min, LFT.random_max)
    LFT.LFMGroup = {
        tank = '',
        healer = '',
        damage1 = '',
        damage2 = '',
        damage3 = '',
    }
end

function LFT.addTank(dungeon, name)
    if LFT.group[dungeon].tank == '' then
        LFT.group[dungeon].tank = name
        --        SendChatMessage('found:tank:' .. dungeon, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        return true
    end
    return false
end

function LFT.addHealer(dungeon, name, faux)
    if LFT.group[dungeon].healer == '' then
        LFT.group[dungeon].healer = name
        if not faux then
            SendChatMessage('found:healer:' .. dungeon, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    end
    return false
end

function LFT.remHealerOrDamage(dungeon, name)
    if LFT.group[dungeon].healer == name then
        LFT.group[dungeon].healer = ''
        --        lfdebug('removed ' .. name .. ' from my ' .. dungeon .. ' group')
    end
    if LFT.group[dungeon].damage1 == name then
        LFT.group[dungeon].damage1 = ''
        --        lfdebug('removed ' .. name .. ' damage1 from my ' .. dungeon .. ' group')
    end
    if LFT.group[dungeon].damage2 == name then
        LFT.group[dungeon].damage2 = ''
        --        lfdebug('removed ' .. name .. ' damage1 from my ' .. dungeon .. ' group')
    end
    if LFT.group[dungeon].damage3 == name then
        LFT.group[dungeon].damage3 = ''
        --        lfdebug('removed ' .. name .. ' damage1 from my ' .. dungeon .. ' group')
    end
end

function LFT.addDamage(dungeon, name, faux)

    if LFT.group[dungeon].damage1 == '' then
        LFT.group[dungeon].damage1 = name
        if not faux then
            SendChatMessage('found:damage:' .. dungeon, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    elseif LFT.group[dungeon].damage2 == '' then
        LFT.group[dungeon].damage2 = name
        if not faux then
            SendChatMessage('found:damage:' .. dungeon, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    elseif LFT.group[dungeon].damage3 == '' then
        LFT.group[dungeon].damage3 = name
        if not faux then
            SendChatMessage('found:damage:' .. dungeon, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    end
    return false --group full on damage
end

function LFT.checkGroupFull()

    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            if LFT.group[data.code].tank ~= '' and
                    LFT.group[data.code].healer ~= '' and
                    LFT.group[data.code].damage1 ~= '' then --dev
                --                    LFT.group[data.code].damage2 ~= '' and
                --                    LFT.group[data.code].damage3 ~= '' then

                LFT.oneGroupFull = true
                LFT.group[data.code].full = true

                return true, data.code, LFT.group[data.code].healer, LFT.group[data.code].damage1, LFT.group[data.code].damage2, LFT.group[data.code].damage3
            else
                LFT.group[data.code].full = false
                LFT.oneGroupFull = false
            end
        end
    end

    return false, false, nil, nil, nil, nil
end

function LFT.dungeonNameFromCode(code)
    for name, data in next, LFT.dungeons do
        if data.code == code then return name end
    end
    return 'Unknown'
end

function LFT.dungeonFromCode(code)
    for name, data in next, LFT.dungeons do
        if data.code == code then return data end
    end
    return false
end

function LFT.AcceptGroupInvite()
    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
    PlaySoundFile("Sound\\Doodad\\BellTollNightElf.wav")
    UIErrorsFrame:AddMessage("[LFT] Group Auto Accept")
end

function LFT.DeclineGroupInvite()
    DeclineGroup()
    StaticPopup_Hide("PARTY_INVITE")
end

function LFT.pairsByKeys(t, f)
    local a = {}
    for n, l in pairs(t) do table.insert(a, l.minLevel)
    end
    table.sort(a, function(a, b) return a < b
    end)
    local i = 0 -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

function LFT.tableSize(t)
    local size = 0
    for _, _ in next, t do size = size + 1 end return size
end

function LFT.checkLFMgroup(someoneDeclined)
    if someoneDeclined then
        if someoneDeclined ~= me then
            lfprint(someoneDeclined .. ' declined role check.')
        end
        return false
    end

    if not LFT.isLeader then return end

    --    lfdebug('check lfm group')
    local currentGroupSize = GetNumPartyMembers() + 1
    --    lfdebug('current g size ' .. currentGroupSize)
    local readyNumber = 0
    if LFT.LFMGroup.tank ~= '' then readyNumber = readyNumber + 1 end
    if LFT.LFMGroup.healer ~= '' then readyNumber = readyNumber + 1 end
    if LFT.LFMGroup.damage1 ~= '' then readyNumber = readyNumber + 1 end
    if LFT.LFMGroup.damage2 ~= '' then readyNumber = readyNumber + 1 end
    if LFT.LFMGroup.damage3 ~= '' then readyNumber = readyNumber + 1 end

    if currentGroupSize == readyNumber then
        --everyone is ready
        LFT.group[LFT.LFMDungeonCode] = {
            tank = LFT.LFMGroup.tank,
            healer = LFT.LFMGroup.healer,
            damage1 = LFT.LFMGroup.damage1,
            damage2 = LFT.LFMGroup.damage2,
            damage3 = LFT.LFMGroup.damage3,
        }
        --        lfdebug('everyone is ready, should hit the queue with this group')
        LFT.sendMinimapDataToParty(LFT.LFMDungeonCode)
        SendAddonMessage('LFT', "weInQueue:" .. LFT.LFMDungeonCode, "PARTY")
    end
end

function LFT.weInQueue(code)

    local dungeonName = 'Unknown'
    for dungeon, data in next, LFT.dungeons do
        if data.code == code then
            LFT.dungeons[dungeon].queued = true
            dungeonName = dungeon
        end
    end

    lfprint('Your group is in the queue for |cff69ccf0' .. dungeonName)

    LFT.findingGroup = true
    LFT.findingMore = true
    LFT.disableDungeonCheckbuttons()

    getglobal('RoleTank'):Disable()
    getglobal('RoleHealer'):Disable()
    getglobal('RoleDamage'):Disable()

    PlaySound('PvpEnterQueue')

    LFT.oneGroupFull = false
    LFT.queueStartTime = time()
    LFTQueue:Show()
    getglobal('LFTMain'):Hide()
end

function LFT.fixMainButton()

    local lfgButton = getglobal('findGroupButton')
    local lfmButton = getglobal('findMoreButton')
    local leaveQueueButton = getglobal('leaveQueueButton')

    lfgButton:Hide()
    lfmButton:Hide()
    leaveQueueButton:Hide()

    lfgButton:Disable()
    lfmButton:Disable()
    leaveQueueButton:Disable()

    LFT.isLeader = LFT.playerIsPartyLeader()
    LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

    local queues = 0
    for dungeon, data in next, LFT.dungeons do
        if data.queued then queues = queues + 1 end
    end

    if queues > 0 then
        lfgButton:Enable()
    end

    if LFT.inGroup then
        lfmButton:Show()
        if GetNumPartyMembers() < 4 and LFT.isLeader and queues > 0 then
            lfmButton:Enable()
        end
        if not LFT.isLeader then
            lfmButton:Disable()
            LFT.disableDungeonCheckbuttons()
        end
    else
        lfgButton:Show()
    end

    if LFT.findingGroup then
        leaveQueueButton:Show()
        leaveQueueButton:Enable()
        if LFT.inGroup then
            if not LFT.isLeader then leaveQueueButton:Disable() end
        end
        lfgButton:Hide()
        lfmButton:Hide()
    end
end

function LFT.sendLFMessage()

    local keyset = {}
    for k in pairs(LFT.group) do
        table.insert(keyset, k)
    end

    local added = {}

    for _, _ in next, LFT.group do
        local newD = keyset[math.random(LFT.tableSize(keyset))]
        if not added[newD] then
            added[newD] = true
            SendChatMessage('LFG:' .. newD .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        else
            --            lfdebug('skipping ' .. newD .. ' already sent')
        end
    end
end

function LFT.isNeededInLFMGroup(role, name)
    if role == 'tank' and LFT.group[LFT.LFMDungeonCode].tank == '' then
        LFT.group[LFT.LFMDungeonCode].tank = name
        return true
    end
    if role == 'healer' and LFT.group[LFT.LFMDungeonCode].healer == '' then
        LFT.group[LFT.LFMDungeonCode].healer = name
        return true
    end
    if role == 'damage' then
        if LFT.group[LFT.LFMDungeonCode].damage1 == '' then
            LFT.group[LFT.LFMDungeonCode].damage1 = name
            return true
        end
        if LFT.group[LFT.LFMDungeonCode].damage2 == '' then
            LFT.group[LFT.LFMDungeonCode].damage2 = name
            return true
        end
        if LFT.group[LFT.LFMDungeonCode].damage3 == '' then
            LFT.group[LFT.LFMDungeonCode].damage3 = name
            return true
        end
    end
    return false
end

function LFT.inviteInLFMGroup(name)
    SendChatMessage("[LFT] " .. LFT.LFMDungeonCode .. " (LFM)", "WHISPER", DEFAULT_CHAT_FRAME.editBox.languageID, name);
    InviteByName(name)
end

function LFT.checkLFMGroupReady()
    if not LFT.isLeader then return end

    if LFT.group[LFT.LFMDungeonCode].tank ~= '' and
            LFT.group[LFT.LFMDungeonCode].healer ~= '' and
            LFT.group[LFT.LFMDungeonCode].damage1 ~= '' then --dev
        --                    LFT.group[LFT.LFMDungeonCode].damage2 ~= '' and
        --                    LFT.group[LFT.LFMDungeonCode].damage3 ~= '' then
        return true
    end
    return false
end

function LFT.sendMinimapDataToParty(mDungeonCode)
    local tank, healer, damage = 0, 0, 0
    if LFT.group[mDungeonCode].tank ~= '' then tank = tank + 1 end
    if LFT.group[mDungeonCode].healer ~= '' then healer = healer + 1 end
    if LFT.group[mDungeonCode].damage1 ~= '' then damage = damage + 1 end
    if LFT.group[mDungeonCode].damage2 ~= '' then damage = damage + 1 end
    if LFT.group[mDungeonCode].damage3 ~= '' then damage = damage + 1 end
    SendAddonMessage("LFT", "minimap:" .. mDungeonCode .. ":" .. tank .. ":" .. healer .. ":" .. damage, "PARTY")
end

function LFT.addOnEnterTooltip(frame, title, text1, text2)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT", -200, -5)
        GameTooltip:AddLine(title)
        if text1 then GameTooltip:AddLine(text1, 1, 1, 1) end
        if text2 then GameTooltip:AddLine(text2, 1, 1, 1) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

function LFT.sendMyVersion()
    SendAddonMessage('LFT', "LFTVersion:" .. addonVer, "PARTY")
    SendAddonMessage('LFT', "LFTVersion:" .. addonVer, "GUILD")
    SendAddonMessage('LFT', "LFTVersion:" .. addonVer, "RAID")
    SendAddonMessage('LFT', "LFTVersion:" .. addonVer, "BATTLEGROUND")
end

-- XML called methods

function acceptRole()
    SendAddonMessage('LFT', "acceptRole:" .. LFT_ROLE, "PARTY")
    getglobal('LFTRoleCheck'):Hide()
    LFTRoleCheck:Hide()
end

function declineRole()
    SendAddonMessage('LFT', "declineRole:", "PARTY")
    getglobal('LFTRoleCheck'):Hide()
    LFTRoleCheck:Hide()
end

function LFT_Toggle()
    if LFT.level == 0 then
        LFT.level = UnitLevel('player')
    end
    if getglobal('LFTMain'):IsVisible() then
        getglobal('LFTMain'):Hide()
    else
        LFT.checkLFTChannel()
        if not LFT.findingGroup then
            LFT.fillAvailableDungeons()
        end

        getglobal('LFTMain'):Show()
        DungeonListFrame_Update()
    end
end

function sayReady()
    if LFT.inGroup then --todo fix when popup is up but player leaves party -- move hide into raid changed
        getglobal('LFTGroupReady'):Hide()
        SendChatMessage('Ready as ' .. LFT_ROLE, "PARTY");
    end
end


function LFTsetRole(role, status, readyCheck)
    local tankCheck = getglobal('RoleTank')
    local healerCheck = getglobal('RoleHealer')
    local damageCheck = getglobal('RoleDamage')

    --ready check window
    local readyCheckTank = getglobal('roleCheckTank')
    local readyCheckHealer = getglobal('roleCheckHealer')
    local readyCheckDamage = getglobal('roleCheckDamage')

    if role == 'tank' then
        readyCheckHealer:SetChecked(false)
        healerCheck:SetChecked(false)

        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        if not status and not readyCheck then tankCheck:SetChecked(true) end
    end
    if role == 'healer' then
        readyCheckTank:SetChecked(false)
        tankCheck:SetChecked(false)

        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        if not status and not readyCheck then healerCheck:SetChecked(true) end
    end
    if role == 'damage' then
        readyCheckTank:SetChecked(false)
        tankCheck:SetChecked(false)

        readyCheckHealer:SetChecked(false)
        healerCheck:SetChecked(false)
        if not status and not readyCheck then damageCheck:SetChecked(true) end
    end

    if readyCheck then
        tankCheck:SetChecked(readyCheckTank:GetChecked())
        healerCheck:SetChecked(readyCheckHealer:GetChecked())
        damageCheck:SetChecked(readyCheckDamage:GetChecked())
    else
        readyCheckTank:SetChecked(tankCheck:GetChecked())
        readyCheckHealer:SetChecked(healerCheck:GetChecked())
        readyCheckDamage:SetChecked(damageCheck:GetChecked())
    end
    LFT_ROLE = role
end

function DungeonListFrame_Update()
    local offset = FauxScrollFrame_GetOffset(getglobal('DungeonListScrollFrame'));
    LFT.fillAvailableDungeons(offset)
end

function DungeonType_OnLoad()
    UIDropDownMenu_Initialize(this, DungeonType_Initialize);
    UIDropDownMenu_SetWidth(160, LFTTypeSelect);
end

function DungeonType_OnClick(a)
    LFT_TYPE = a
    UIDropDownMenu_SetText(LFT.types[LFT_TYPE], getglobal('LFTTypeSelect'))
    getglobal('LFTDungeonsText'):SetText(LFT.types[LFT_TYPE])
    LFT.fillAvailableDungeons()
end

function DungeonType_Initialize()
    for id, type in pairs(LFT.types) do
        local info = {}
        info.text = type
        info.value = id
        info.arg1 = id
        info.checked = LFT_TYPE == id
        info.func = DungeonType_OnClick
        if not LFT.findingGroup then
            UIDropDownMenu_AddButton(info)
        end
    end
end


function LFT_HideMinimap()
    for i, f in LFT.minimapFrames do
        LFT.minimapFrames[i]:Hide()
    end
    getglobal('LFTGroupStatus'):Hide()
end

function LFT_ShowMinimap()

    if LFT.findingGroup or LFT.findingMore then
        local dungeonIndex = 0
        for dungeonCode, data in next, LFT.group do
            local tank = 0
            local healer = 0
            local damage = 0
            if data.tank ~= '' then tank = tank + 1 end
            if data.healer ~= '' or LFT_ROLE == 'healer' then healer = healer + 1 end
            if data.damage1 ~= '' or LFT_ROLE == 'damage' then damage = damage + 1 end
            if data.damage2 ~= '' then damage = damage + 1 end
            if data.damage3 ~= '' then damage = damage + 1 end

            local dungeon = LFT.dungeonFromCode(dungeonCode)

            if not LFT.minimapFrames[dungeonCode] then
                LFT.minimapFrames[dungeonCode] = CreateFrame('Frame', "LFTMinimap_" .. dungeonCode, UIParent, "LFTMinimapDungeonTemplate")
            end

            local background = ''
            local dungeonName = 'unknown'
            for d, data2 in next, LFT.dungeons do
                if data2.code == dungeonCode then
                    background = data2.background
                    dungeonName = d
                end
            end

            LFT.minimapFrames[dungeonCode]:Show()
            LFT.minimapFrames[dungeonCode]:SetPoint("TOP", getglobal("LFTGroupStatus"), "TOP", 0, -25 - 32 * (dungeonIndex))
            getglobal('LFTMinimap_' .. dungeonCode .. 'Background'):SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
            getglobal('LFTMinimap_' .. dungeonCode .. 'DungeonName'):SetText(dungeonName)

            getglobal('LFTMinimap_' .. dungeonCode .. 'NrTank'):SetText(tank .. '/1')
            getglobal('LFTMinimap_' .. dungeonCode .. 'NrHealer'):SetText(healer .. '/1')
            getglobal('LFTMinimap_' .. dungeonCode .. 'NrDamage'):SetText(damage .. '/3')

            dungeonIndex = dungeonIndex + 1
        end

        getglobal('LFTGroupStatus'):SetPoint("TOPRIGHT", getglobal("LFT_Minimap"), "BOTTOMLEFT", 8, 8)
        getglobal('LFTGroupStatus'):SetHeight(dungeonIndex * 32 + 80)
        getglobal('LFTGroupStatusTimeInQueue'):SetText('Time in Queue: ' .. SecondsToTime(time() - LFT.queueStartTime))
        getglobal('LFTGroupStatus'):Show()
    else
    end
end

function queueForFromButton(Bcode)

    if true then return false end --dev

    local codeEx = string.split(Bcode, '_')
    local Qcode = codeEx[2]
    for code, data in next, LFT.availableDungeons do
        if code == Qcode and not LFT.findingGroup then
            getglobal('Dungeon_' .. data.code):SetChecked(not getglobal('Dungeon_' .. data.code):GetChecked())
            queueFor(Bcode, getglobal('Dungeon_' .. data.code):GetChecked())
        end
    end
end

function queueFor(name, status)
    local dugeonCode = ''
    for dungeon, data in next, LFT.dungeons do
        local dung = string.split(name, '_')
        dugeonCode = dung[2]
        if dugeonCode == data.code then
            if status then
                LFT.dungeons[dungeon].queued = true
            else
                LFT.dungeons[dungeon].queued = false
            end
        end
    end

    local queues = 0
    for dungeon, data in next, LFT.dungeons do
        if data.queued then queues = queues + 1 end
    end

    if queues == 1 and LFT.inGroup then
        LFT.disableDungeonCheckbuttons(dugeonCode)
        --        lfdebug('should lock')
    else
        LFT.enableDungeonCheckbuttons()
        --        lfdebug('should enable')
    end

    LFT.fixMainButton()
end

LFT.findingMore = false

function findMore()

    -- find queueing dungeon
    local qDungeon = ''
    for i, frame in next, LFT.availableDungeons do
        if getglobal("Dungeon_" .. frame.code):GetChecked() then
            qDungeon = frame.code
        end
    end

    LFT.LFMDungeonCode = qDungeon
    LFT.findingMore = true
    SendAddonMessage("LFT", "roleCheck:" .. qDungeon, "PARTY")

    LFT.fixMainButton()
end

function findGroup()

    LFT.resetGroup()
    LFT.findingGroup = true
    LFTQueue:Show()

    LFT.disableDungeonCheckbuttons()

    getglobal('RoleTank'):Disable()
    getglobal('RoleHealer'):Disable()
    getglobal('RoleDamage'):Disable()

    PlaySound('PvpEnterQueue')

    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            lfprint('You are in the queue for |cff69ccf0' .. LFT.dungeonNameFromCode(data.code))
            SendChatMessage('LFG:' .. data.code .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
    end

    LFT.oneGroupFull = false
    LFT.queueStartTime = time()

    LFT.fixMainButton()
end

function leaveQueue()

    LFTQueue:Hide()

    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            if LFT_TYPE == 2 then --random dungeon, dont uncheck if it comes here from the button
                getglobal("Dungeon_" .. data.code):SetChecked(false)
                LFT.dungeons[dungeon].queued = false
            end
            if LFT.inGroup then
                LFT.enableDungeonCheckbuttons()
                LFT.disableDungeonCheckbuttons(data.code)
                lfprint('Your group has left the queue for |cff69ccf0' .. LFT.dungeonNameFromCode(data.code))
            else
                lfprint('You have left the queue for |cff69ccf0' .. LFT.dungeonNameFromCode(data.code))
            end
        end
    end

    if not LFT.inGroup then
        LFT.enableDungeonCheckbuttons()
    end

    LFT.GetPossibleRoles()
    LFTsetRole(LFT_ROLE)

    LFT.findingGroup = false
    LFT.findingMore = false

    if LFT.isLeader then
        SendAddonMessage("LFT", "leaveQueue:now", "PARTY")
    end

    LFT.fixMainButton()
end

-- slash commands

SLASH_LFT1 = "/lft"
SlashCmdList["LFT"] = function(cmd)
    if cmd then
        if string.sub(cmd, 1, 3) == 'who' then
            LFTWhoCounter:Show()
            SendChatMessage('whoLFT:' .. addonVer, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        if string.sub(cmd, 1, 3) == 'hp' then
        end
    end
end


-- dungeons


LFT.dungeons = {
    ['Ragefire Chasm'] = { minLevel = 13, maxLevel = 18, code = 'rfc', queued = false, canQueue = true, background = 'ragefirechasm' },
    ['Wailing Caverns'] = { minLevel = 17, maxLevel = 24, code = 'wc', queued = false, canQueue = true, background = 'wailingcaverns' },
    ['The Deadmines'] = { minLevel = 19, maxLevel = 24, code = 'dm', queued = false, canQueue = true, background = 'deadmines' },
    ['Shadowfang Keep'] = { minLevel = 22, maxLevel = 30, code = 'sfk', queued = false, canQueue = true, background = 'shadowfangkeep' },
    ['Blackfathom Deeps'] = { minLevel = 23, maxLevel = 32, code = 'bfd', queued = false, canQueue = true, background = 'blackfathomdeeps' },
    ['The Stockade'] = { minLevel = 22, maxLevel = 30, code = 'stocks', queued = false, canQueue = true, background = 'stormwindstockades' },
    ['Gnomeregan'] = { minLevel = 29, maxLevel = 38, code = 'gnomer', queued = false, canQueue = true, background = 'gnomeregan' },
    ['Razorfen Kraul'] = { minLevel = 29, maxLevel = 38, code = 'rfk', queued = false, canQueue = true, background = 'razorfenkraul' },
    ['Scarlet Monastery Graveyard'] = { minLevel = 27, maxLevel = 36, code = 'smgy', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Scarlet Monastery Library'] = { minLevel = 28, maxLevel = 39, code = 'smlib', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Scarlet Monastery Armory'] = { minLevel = 32, maxLevel = 41, code = 'smarmory', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Scarlet Monastery Cathedral'] = { minLevel = 35, maxLevel = 45, code = 'smcath', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Razorfen Downs'] = { minLevel = 36, maxLevel = 46, code = 'rfd', queued = false, canQueue = true, background = 'razorfendowns' },
    ['Uldaman'] = { minLevel = 50, maxLevel = 51, code = 'ulda', queued = false, canQueue = true, background = 'uldaman' },
    ['Zul\'Farrak'] = { minLevel = 44, maxLevel = 54, code = 'zf', queued = false, canQueue = true, background = 'zulfarak' },
    ['Maraudon'] = { minLevel = 47, maxLevel = 55, code = 'mara', queued = false, canQueue = true, background = 'maraudon' },
    ['Temple of Atal\'Hakkar'] = { minLevel = 50, maxLevel = 60, code = 'st', queued = false, canQueue = true, background = 'sunkentemple' },
    ['Blackrock Depths'] = { minLevel = 52, maxLevel = 60, code = 'brd', queued = false, canQueue = true, background = 'blackrockdepths' },
    ['Lower Blackrock Spire'] = { minLevel = 55, maxLevel = 60, code = 'lbrs', queued = false, canQueue = true, background = 'blackrockspire' },
    ['Dire Maul North'] = { minLevel = 57, maxLevel = 60, code = 'dmn', queued = false, canQueue = true, background = 'diremaul' },
    ['Dire Maul East'] = { minLevel = 55, maxLevel = 60, code = 'dme', queued = false, canQueue = true, background = 'diremaul' },
    ['Dire Maul West'] = { minLevel = 57, maxLevel = 60, code = 'dmw', queued = false, canQueue = true, background = 'diremaul' },
    ['Scholomance'] = { minLevel = 58, maxLevel = 60, code = 'scholo', queued = false, canQueue = true, background = 'scholomance' },
    ['Stratholme UD'] = { minLevel = 58, maxLevel = 60, code = 'stratud', queued = false, canQueue = true, background = 'stratholme' },
    ['Stratholme Live'] = { minLevel = 58, maxLevel = 60, code = 'stratlive', queued = false, canQueue = true, background = 'stratholme' },
}

-- utils

function LFT.ver(ver)
    return tonumber(string.sub(ver, 1, 1)) * 1000 +
            tonumber(string.sub(ver, 3, 3)) * 100 +
            tonumber(string.sub(ver, 5, 5)) * 10 +
            tonumber(string.sub(ver, 7, 7)) * 1
end

function LFT.playerIsPartyLeader()
    return GetPartyLeaderIndex() == 0 and GetNumPartyMembers() > 0
end

function LFT.ucFirst(a)
    return string.upper(string.sub(a, 1, 1)) .. string.lower(string.sub(a, 2, string.len(a)))
end

function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end

