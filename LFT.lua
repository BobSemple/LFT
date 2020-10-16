local LFT = CreateFrame("Frame")
local me = UnitName('player')

LFT.class = ''
LFT.channel = 'LFT'
LFT.channelIndex = 0
LFT.level = UnitLevel('player')
LFT.findingGroup = false
LFT:RegisterEvent("ADDON_LOADED")
LFT:RegisterEvent("PLAYER_ENTERING_WORLD")
LFT:RegisterEvent("RAID_TARGET_UPDATE")
LFT.availableDungeons = {}
LFT.group = {}
LFT.oneGroupFull = false
LFT.groupFullCode = ''
LFT.acceptNextInvite = false
LFT.queueStartTime = 0


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
            lfdebug('inviting : ' .. LFT.group[LFT.groupFullCode].healer)
            InviteByName(LFT.group[LFT.groupFullCode].healer)
        end
        if this.inviteIndex == 3 then
            lfdebug('inviting : ' .. LFT.group[LFT.groupFullCode].dps1)
            InviteByName(LFT.group[LFT.groupFullCode].dps1)
        end
        if this.inviteIndex == 4 then
            lfdebug('inviting : ' .. LFT.group[LFT.groupFullCode].dps2)
            InviteByName(LFT.group[LFT.groupFullCode].dps2)
        end
        if this.inviteIndex == 5 then
            lfdebug('inviting : ' .. LFT.group[LFT.groupFullCode].dps3)
            InviteByName(LFT.group[LFT.groupFullCode].dps3)
            LFTInvite:Hide()
        end
    end
end)

local LFTComms = CreateFrame("Frame")
LFTComms:Hide()
LFTComms:RegisterEvent("CHAT_MSG_CHANNEL")
LFTComms:RegisterEvent("CHAT_MSG_WHISPER")
LFTComms:RegisterEvent("PARTY_INVITE_REQUEST")


LFTComms:SetScript("OnEvent", function()
    if event then
        if event == 'PARTY_INVITE_REQUEST' and LFT.acceptNextInvite then
            LFT.AcceptGroupInvite()
            LFT.acceptNextInvite = false
        end
        if event == 'CHAT_MSG_WHISPER' and string.find(arg1, '[LFT]', 1, true) and
                string.find(arg1, 'party ready', 1, true) then
            local mEx = string.split(arg1, ' ')
            LFT.acceptNextInvite = true
            lfdebug('should accept next invite')
        end
        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFT.channelIndex and not LFT.oneGroupFull then -- and arg2 ~= me then
            lfdebug('chat msg channel msg : ' .. arg1)

            local spamSplit = string.split(arg1, ':')
            local mDungeonCode = spamSplit[2]
            local mRole = spamSplit[3] --other's role

            for dungeon, data in next, LFT.dungeons do
                if data.queued and data.code == mDungeonCode then

                    if LFT_ROLE == 'tank' then
                        LFT.group[mDungeonCode].tank = me
                        lfdebug('added tank me = ' .. me)

                        if mRole == 'healer' and LFT.group[mDungeonCode].healer == '' then
                            LFT.group[mDungeonCode].healer = arg2
                            lfdebug('added healer = ' .. arg2)
                        end

                        if mRole == 'damage' then
                            LFT.addDps(mDungeonCode, arg2)
                        end
                    end

                    --pseudo fill group for tooltip display
                    if LFT_ROLE == 'healer' then
                        LFT.group[mDungeonCode].healer = me
                        lfdebug('added pseudo healer me = ' .. me)

                        if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                            LFT.group[mDungeonCode].tank = arg2
                            lfdebug('added pseudo tank = ' .. arg2)
                        end

                        if mRole == 'damage' then
                            LFT.addDps(mDungeonCode, arg2, true)
                        end
                    end

                    if LFT_ROLE == 'dps' then
                        LFT.addDps(dungeon, me, true)
                        if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                            LFT.group[mDungeonCode].tank = arg2
                            lfdebug('added pseudo tank = ' .. arg2)
                        end
                        if mRole == 'healer' and LFT.group[mDungeonCode].healer == '' then
                            LFT.group[mDungeonCode].healer = arg2
                            lfdebug('added pseudo healer = ' .. arg2)
                        end
                    end
                end
            end

            if LFT_ROLE == 'tank' then
                local groupFull, code, healer, dps1, dps2, dps3 = LFT.checkGroupFull()

                if groupFull then
                    LFT.groupFullCode = code
                    lfprint('YOUR GROUP IS READY')

                    SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER", "Common", healer);
                    SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER", "Common", dps1);
                    SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER", "Common", dps2);
                    SendChatMessage("[LFT] " .. code .. " party ready ", "WHISPER", "Common", dps3);

                    LFTInvite:Show()
                end
            end
        end
    end
end)

function lfprint(a)
    if a == nil then
        DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[LFT]|cff0070de:' .. time() .. '|cffffffff attempt to print a nil value.')
        return false
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[LFT] |cffffffff" .. a)
end

function lferror(a)
    DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[LFTError]|cff0070de:' .. time() .. '|cffffffff[' .. a .. ']')
end

function lfdebug(a)
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
            lfprint(LFT_ROLE)
            if not LFT_ROLE then
                LFT_ROLE = LFT.GetPossibleRoles()
            else
                LFTsetRole(LFT_ROLE)
            end
        end
        if event == "PLAYER_ENTERING_WORLD" then
            --            local zone = GetZoneText
            --            for dungeon, data in next, LFT.dungeons do
            --                if dungeon == zone then
            --                    lfdebug('found player in ' .. )
            --                end
            --            end
        end
        if event == "RAID_TARGET_UPDATE" then
            if LFT.findingGroup then
                LFT.findingGroup = false
            end
            LFT.fixMainButton()
        end
    end
end)

function LFT.init()
    local _, uClass = UnitClass('player')

    LFT.class = string.lower(uClass)
    LFT.channel = 'LFT'
    LFT.channelIndex = 0
    LFT.level = UnitLevel('player')
    LFT.findingGroup = false
    LFT:RegisterEvent("ADDON_LOADED")
    LFT.availableDungeons = {}
    LFT.group = {}
    LFT.oneGroupFull = false
    LFT.groupFullCode = ''
    LFT.acceptNextInvite = false
    LFT.minimapFrameIndex = 0

    LFT.fixMainButton()

    LFT.fillAvailableDungeons()
end


LFTQueue:SetScript("OnShow", function()
    this.startTime = GetTime()
    this.lastTime = {
        tank = 0,
        dps = 0,
        heal = 0,
        reset = 0
    }
end)

LFTQueue:SetScript("OnUpdate", function()
    local plus = 0.15 --seconds
    local gt = GetTime() * 1000 --22.123 -> 22123
    local st = (this.startTime + plus) * 1000 -- (22.123 + 0.1) * 1000 =  22.223 * 1000 = 22223
    if gt >= st and LFT.findingGroup then
        this.startTime = GetTime()

        local cSecond = date("%S", time())

        getglobal('LFTTitleTime'):SetText(cSecond)

        if cSecond == '59' and this.lastTime.reset ~= time() then
            LFT.resetGroup()
            this.lastTime.reset = time()
        end

        if (cSecond == '00' or cSecond == '30') and LFT_ROLE == 'tank' and this.lastTime.tank ~= time() then

            for dungeon, data in next, LFT.dungeons do
                if data.queued then
                    LFT.group[data.code].tank = me
                end
            end
            this.lastTime.tank = time()
        end

        if (cSecond == '10' or cSecond == '40') and LFT_ROLE == 'healer' and this.lastTime.heal ~= time() then
            for dungeon, data in next, LFT.dungeons do
                if data.queued then
                    LFT.sendLFMessage('LFG:' .. data.code .. ':' .. LFT_ROLE)
                end
            end
            this.lastTime.heal = time()
        end

        if (cSecond == '15' or cSecond == '15') and LFT_ROLE == 'damage' and this.lastTime.dps ~= time() then
            for dungeon, data in next, LFT.dungeons do
                if data.queued then
                    LFT.sendLFMessage('LFG:' .. data.code .. ':' .. LFT_ROLE)
                end
            end
            this.lastTime.dps = time()
        end

        getglobal('LFT_MinimapEye'):SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking' .. LFT.minimapFrameIndex)

        if LFT.minimapFrameIndex < 28 then
            LFT.minimapFrameIndex = LFT.minimapFrameIndex + 1
        else
            LFT.minimapFrameIndex = 0
        end
    end
end)

SLASH_LFT1 = "/lft"
SlashCmdList["LFT"] = function(cmd)
    if cmd then
        if string.sub(cmd, 1, 3) == 'hp' then
        end
    end
end

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
        lfprint("NOT IN LFT")
        JoinChannelByName(LFT.channel)
    else
        lfprint("IN lft channel:" .. LFT.channelIndex)
    end
end

function LFTsetRole(role, status)
    local tankCheck = getglobal('RoleTank')
    local healerCheck = getglobal('RoleHealer')
    local damageCheck = getglobal('RoleDamage')

    if role == 'tank' then
        healerCheck:SetChecked(false)
        damageCheck:SetChecked(false)
        if not status then tankCheck:SetChecked(true) end --todo maybe change to status == nil
    end
    if role == 'healer' then
        tankCheck:SetChecked(false)
        damageCheck:SetChecked(false)
        if not status then healerCheck:SetChecked(true) end
    end
    if role == 'damage' then
        tankCheck:SetChecked(false)
        healerCheck:SetChecked(false)
        if not status then damageCheck:SetChecked(true) end
    end
    LFT_ROLE = role
end

function LFT.GetPossibleRoles()
    local tankCheck = getglobal('RoleTank')
    local healerCheck = getglobal('RoleHealer')
    local damageCheck = getglobal('RoleDamage')
    tankCheck:Disable()
    tankCheck:SetChecked(false)
    healerCheck:Disable()
    healerCheck:SetChecked(false)
    damageCheck:Disable()
    damageCheck:SetChecked(false)
    if LFT.class == 'warrior' then
        tankCheck:Enable();
        tankCheck:SetChecked(true)
        damageCheck:Enable()
        damageCheck:SetChecked(false)
        return 'tank'
    end
    if LFT.class == 'paladin' or LFT.class == 'druid' then
        tankCheck:Enable();
        tankCheck:SetChecked(false)
        healerCheck:Enable()
        healerCheck:SetChecked(true)
        damageCheck:Enable()
        damageCheck:SetChecked(false)
        return 'healer'
    end
    if LFT.class == 'warlock' or LFT.class == 'hunter' then
        tankCheck:Disable();
        tankCheck:SetChecked(false)
        healerCheck:Disable()
        healerCheck:SetChecked(false)
        damageCheck:Enable()
        damageCheck:SetChecked(true)
        return 'damage'
    end
    return 'damage'
end

function fillDungeons() -- to be removed
    LFT.fillAvailableDungeons()
end

function LFT.sendLFMessage(msg)
    lfdebug(msg)
    SendChatMessage(msg, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel));
end

function LFT.fillAvailableDungeons()
    --clear checkboxes

    LFT.level = UnitLevel('player')

    local dungeonIndex = 0
    for dungeon, data in next, LFT.dungeons do
        if LFT.level >= data.minLevel and LFT.level <= data.maxLevel then

            dungeonIndex = dungeonIndex + 1
            if not LFT.availableDungeons[dungeonIndex] then
                LFT.availableDungeons[dungeonIndex] = CreateFrame("CheckButton", "Dungeon_" .. data.code, getglobal("LFTMain"), "LFT_DungeonCheck")
            end

            local color = ''
            if LFT.level == data.minLevel then color = '|cffff222a' end
            if LFT.level == data.maxLevel then color = '|cff1fba1f' end
            getglobal('Dungeon_' .. data.code .. 'Text'):SetText(color .. dungeon)
            getglobal('Dungeon_' .. data.code .. 'Levels'):SetText(color .. '(' .. data.minLevel .. ' - ' .. data.maxLevel .. ')')
            --error here when dinging and dungeons change

            LFT.availableDungeons[dungeonIndex]:SetPoint("TOP", getglobal("LFTMain"), "TOP", -145, -165 - 20 * dungeonIndex)
            LFT.availableDungeons[dungeonIndex].code = data.code
        end
    end
end

function queueFor(name, status)

    for dungeon, data in next, LFT.dungeons do
        local dung = string.split(name, '_')

        if dung[2] == data.code then
            if status then
                LFT.dungeons[dungeon].queued = true
                --                lfprint(dungeon .. ' queued ')
            else
                LFT.dungeons[dungeon].queued = false
                --                lfprint(dungeon .. ' un - queued ')
            end
        end
    end

    LFT.fixMainButton()
end

function LFT_Toggle()
    if getglobal('LFTMain'):IsVisible() then
        getglobal('LFTMain'):Hide()
    else
        LFT.checkLFTChannel()
        LFT.fillAvailableDungeons()

        getglobal('LFTMain'):Show()
    end
end

function findGroup()

    LFT.resetGroup()

    LFT.findingGroup = not LFT.findingGroup

    if LFT.findingGroup then
        LFTQueue:Show()

        for i, frame in next, LFT.availableDungeons do
            getglobal("Dungeon_" .. frame.code):Disable()
        end

        getglobal('RoleTank'):Disable()
        getglobal('RoleHealer'):Disable()
        getglobal('RoleDamage'):Disable()

        PlaySound('PvpEnterQueue')

        for dungeon, data in next, LFT.dungeons do
            if data.queued then
                lfprint('You are in the queue for |cff69ccf0' .. LFT.dungeonNameFromCode(data.code))
            end
        end

        LFT.queueStartTime = time()
        lfprint(LFT.queueStartTime)

    else
        LFTQueue:Hide()

        for dungeon, data in next, LFT.dungeons do
            if data.queued then
                lfprint('You have left the queue for |cff69ccf0' .. LFT.dungeonNameFromCode(data.code))
            end
        end

        for i, frame in next, LFT.availableDungeons do
            getglobal("Dungeon_" .. frame.code):Enable()
        end

        getglobal('RoleTank'):Enable()
        getglobal('RoleHealer'):Enable()
        getglobal('RoleDamage'):Enable()
    end

    LFT.fixMainButton()
end

function LFT.resetGroup()
    lfdebug('reset call')
    LFT.group = {};
    LFT.oneGroupFull = false
    LFT.groupFullCode = ''
    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            local tank = ''
            if LFT_ROLE == 'tank' then tank = me end
            LFT.group[data.code] = {
                tank = tank,
                healer = '',
                dps1 = '',
                dps2 = '', --''Holystrike',
                dps3 = '', --''Holystrike'
            }
        end
    end
end

function LFT.addDps(dungeon, name, pseudo)
    local ps = ''
    if pseudo then ps = 'pseudo' end
    if LFT.group[dungeon].dps1 == '' then
        LFT.group[dungeon].dps1 = name
        lfdebug('added ' .. ps .. ' dps1 = ' .. name)
        return true
    elseif LFT.group[dungeon].dps2 == '' then
        LFT.group[dungeon].dps2 = name
        lfdebug('added ' .. ps .. ' dps2 = ' .. name)
        return true
    elseif LFT.group[dungeon].dps3 == '' then
        LFT.group[dungeon].dps3 = name
        lfdebug('added ' .. ps .. ' dps3 = ' .. name)
        return true
    end
    lfdebug('dps list full, didnt add ' .. name)
    return false --group full on dps
end

function LFT.checkGroupFull()
    lfdebug('group full check')
    for dungeon, data in next, LFT.dungeons do
        if data.queued then

            if LFT.group[data.code].tank ~= '' and
                    LFT.group[data.code].healer ~= '' and
                    LFT.group[data.code].dps1 ~= '' and
                    LFT.group[data.code].dps2 ~= '' and
                    LFT.group[data.code].dps3 ~= '' then
                lfdebug('group full for ' .. dungeon)
                lfdebug(LFT.group[data.code].tank .. ' ' .. LFT.group[data.code].healer ..
                        ' ' .. LFT.group[data.code].dps1 .. ' ' .. LFT.group[data.code].dps2 ..
                        ' ' .. LFT.group[data.code].dps3)

                LFT.oneGroupFull = true
                LFT.group[data.code].full = true

                return true, data.code, LFT.group[data.code].healer, LFT.group[data.code].dps1, LFT.group[data.code].dps3, LFT.group[data.code].dps3
            else
                lfdebug('group not full ' .. data.code)
                lfdebug(LFT.group[data.code].tank .. ', ' .. LFT.group[data.code].healer ..
                        ', ' .. LFT.group[data.code].dps1 .. ', ' .. LFT.group[data.code].dps2 ..
                        ', ' .. LFT.group[data.code].dps3 .. '.')

                LFT.group[data.code].full = false
                LFT.oneGroupFull = false
            end
        end
    end

    return false, false, nil, nil, nil, nil
end

--function getPlayerClass(name)
--    for i = 0, GetNumRaidMembers() do
--        if (GetRaidRosterInfo(i)) then
--            local n = GetRaidRosterInfo(i);
--            if (name == n) then
--                local _, unitClass = UnitClass('raid' .. i) --standard
--                return string.lower(unitClass)
--            end
--        end
--    end
--    return 'priest'
--end

LFT.dungeons = {
    ['Ragefire Chasm'] = { minLevel = 13, maxLevel = 18, code = 'rfc', queued = false, background = 'ragefirechasm' },
    ['Wailing Caverns'] = { minLevel = 17, maxLevel = 24, code = 'wc', queued = false, background = 'wailingcaverns' },
    ['The Deadmines'] = { minLevel = 18, maxLevel = 23, code = 'dm', queued = false, background = 'deadmines' },
    ['Shadowfang Keep'] = { minLevel = 22, maxLevel = 30, code = 'sfk', queued = false, background = 'shadowfangkeep' },
    ['Blackfathom Deeps'] = { minLevel = 20, maxLevel = 30, code = 'bfd', queued = false, background = 'blackfathomdeeps' },
    ['The Stockade'] = { minLevel = 22, maxLevel = 30, code = 'stocks', queued = false, background = 'stormwindstockades' },
    ['Gnomeregan'] = { minLevel = 24, maxLevel = 34, code = 'gnomer', queued = false, background = 'gnomeregan' },
    ['Razorfen Kraul'] = { minLevel = 30, maxLevel = 40, code = 'rfk', queued = false, background = 'razorfenkraul' },
    ['Scarlet Monastery Graveyard'] = { minLevel = 26, maxLevel = 45, code = 'smgy', queued = false, background = 'scarletmonastery' },
    ['Scarlet Monastery Library'] = { minLevel = 26, maxLevel = 45, code = 'smlib', queued = false, background = 'scarletmonastery' },
    ['Scarlet Monastery Armory'] = { minLevel = 26, maxLevel = 45, code = 'smarmory', queued = false, background = 'scarletmonastery' },
    ['Scarlet Monastery Cathedral'] = { minLevel = 26, maxLevel = 45, code = 'smcath', queued = false, background = 'scarletmonastery' },
    ['Razorfen Downs'] = { minLevel = 40, maxLevel = 50, code = 'rfd', queued = false, background = 'razorfendowns' },
    ['Uldaman'] = { minLevel = 35, maxLevel = 45, code = 'ulda', queued = false, background = 'uldaman' },
    ['Zul\'Farrak'] = { minLevel = 42, maxLevel = 46, code = 'zf', queued = false, background = 'zulfarak' },
    ['Maraudon'] = { minLevel = 46, maxLevel = 55, code = 'mara', queued = false, background = 'maraudon' },
    ['Temple of Atal\'Hakkar'] = { minLevel = 55, maxLevel = 60, code = 'st', queued = false, background = 'sunkentemple' },
    ['Blackrock Depths'] = { minLevel = 52, maxLevel = 60, code = 'brd', queued = false, background = 'blackrockdepths' },
    ['Lower Blackrock Spire'] = { minLevel = 55, maxLevel = 60, code = 'lbrs', queued = false, background = 'blackrockspire' },
    ['Dire Maul North'] = { minLevel = 55, maxLevel = 60, code = 'dmn', queued = false, background = 'diremaul' },
    ['Dire Maul East'] = { minLevel = 55, maxLevel = 60, code = 'dme', queued = false, background = 'diremaul' },
    ['Dire Maul West'] = { minLevel = 55, maxLevel = 60, code = 'dmw', queued = false, background = 'diremaul' },
    ['Scholomance'] = { minLevel = 58, maxLevel = 60, code = 'scholo', queued = false, background = 'scholomance' },
    ['Stratholme UD'] = { minLevel = 58, maxLevel = 60, code = 'stratud', queued = false, background = 'stratholme' },
    ['Stratholme Live'] = { minLevel = 58, maxLevel = 60, code = 'stratlive', queued = false, background = 'stratholme' },
}

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


function LFT.AcceptGroupInvite()
    AcceptGroup();
    StaticPopup_Hide("PARTY_INVITE");
    PlaySoundFile("Sound\\Doodad\\BellTollNightElf.wav");
    UIErrorsFrame:AddMessage("[LFT] Group Auto Accept");
end

function LFT.levelSort(a)
    local r = {}
    local level = 0
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

function LFT.fixMainButton()

    local buttonEnabled = true
    local buttonText = 'Find Group'
    local inRaid = GetNumRaidMembers() > 0
    local inGroup = not inRaid and GetNumPartyMembers() > 0

    if inGroup then
        if not UnitIsGroupLeader('player') then
            buttonEnabled = false
        end
        if GetNumPartyMembers() < 5 then
            buttonText = 'Find more'
        end
    end

    if LFT.findingGroup then
        buttonText = 'Leave Queue'
    end

    local queues = 0
    for dungeon, data in next, LFT.dungeons do
        if data.queued then queues = queues + 1 end
    end

    buttonEnabled = queues > 0

    if buttonEnabled then
        getglobal('findGroupButton'):Enable()
    else
        getglobal('findGroupButton'):Disable()
    end

    getglobal('findGroupButton'):SetText(buttonText)
end

function LFT_ShowTooltip(t)
    GameTooltip:SetOwner(t, "ANCHOR_BOTTOMLEFT", 0, 0)

    GameTooltip:AddLine('Looking For Turtles', 1, 1, 1)

    if LFT.findingGroup then

        for dungeonCode, data in next, LFT.group do
            local tank = 0
            local healer = 0
            local dps = 0
            if data.tank ~= '' then tank = tank + 1 end
            if data.healer ~= '' or LFT_ROLE == 'healer' then healer = healer + 1 end
            if data.dps1 ~= '' or LFT_ROLE == 'damage' then dps = dps + 1 end
            if data.dps2 ~= '' then dps = dps + 1 end
            if data.dps3 ~= '' then dps = dps + 1 end

            local dungeon = LFT.dungeonFromCode(dungeonCode)
            GameTooltip:AddLine(LFT.dungeonNameFromCode(dungeonCode) .. ' (T:' .. tank .. '/1 H:' .. healer .. '/1 D:' .. dps .. '/3)')
        end

        GameTooltip:AddLine(' ')
        GameTooltip:AddLine('Time in Queue: ' .. SecondsToTime(time() - LFT.queueStartTime))

    else
        GameTooltip:AddLine('Click to open')
    end

    GameTooltip:Show()
end
