local rule = ArkInventoryRules:NewModule( "ArkInventoryRules_RestedXP" )

-- Guide commands that reference items, and how to read the item IDs from the parsed element.
-- Left out on purpose: .destroy (items the guide throws away) and .usespell (spells, not items).
local function addId( set, value )
	if type( value ) == "number" then
		set[value] = true
	elseif type( value ) == "string" then
		for id in string.gmatch( value, "%d+" ) do
			set[tonumber( id )] = true
		end
	end
end

local READERS = {
	collect = function( e, set ) addId( set, e.id ) addId( set, e.ids ) end,
	collectmultiple = function( e, set ) addId( set, e.id ) addId( set, e.ids ) end,
	questitemcount = function( e, set ) addId( set, e.id ) end,
	buy = function( e, set ) addId( set, e.id ) end,
	equip = function( e, set ) addId( set, e.id ) end,
	retrieveitem = function( e, set ) addId( set, e.id ) end,
	use = function( e, set )
		for id in pairs( e.activeItems or { } ) do addId( set, id ) end
	end,
	itemcount = function( e, set )
		for _, v in ipairs( type( e.ids ) == "table" and e.ids or { } ) do addId( set, v ) end
	end,
	bankdeposit = function( e, set )
		for _, v in ipairs( e.items or { } ) do addId( set, v ) end
	end,
	bankwithdraw = function( e, set )
		for _, v in ipairs( e.items or { } ) do addId( set, v ) end
	end,
}

-- How many guides after the loaded one count as well. Guides often only say "keep these, you need
-- them later" in the step text, and the matching collect command is in the next guide.
local NEXT_GUIDES = 1

local function QuestOpen( questId )
	questId = tonumber( questId )
	if not questId or questId <= 0 then return false end
	if C_QuestLog and C_QuestLog.IsOnQuest then
		return C_QuestLog.IsOnQuest( questId ) == true
	end
	if GetQuestLogIndexByID then
		return ( GetQuestLogIndexByID( questId ) or 0 ) > 0
	end
	return false
end

local function QuestTurnedIn( questId )
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		return C_QuestLog.IsQuestFlaggedCompleted( questId ) == true
	end
	if IsQuestFlaggedCompleted then
		return IsQuestFlaggedCompleted( questId ) == true
	end
	return false
end

-- Items from steps already behind you still count while their quest is in the quest log,
-- because the turn-in step only names the quest, not the items it needs.
local function collectQuestOpen( e ) return QuestOpen( e.questId ) end
local STILL_NEEDED = {
	collect = collectQuestOpen,
	collectmultiple = collectQuestOpen,
	questitemcount = function( e )
		for _, questId in ipairs( e.quests or { } ) do
			if QuestOpen( questId ) then return true end
		end
		return false
	end,
}

-- per command: { [itemID] = true }; all = union of every command
local guideItems = { all = { } }
local guideKey

local function RXPData( )
	local rxp = _G.RXP
	if type( rxp ) ~= "table" or type( rxp.currentGuide ) ~= "table" or type( rxp.currentGuide.steps ) ~= "table" then
		return nil
	end
	return rxp.currentGuide
end

-- The guide named by #next, parsed and filtered for this character like RestedXP does when it loads it.
-- #next may list several guides separated by ";", each optionally prefixed with "<group>\";
-- RestedXP takes the first one that is active for the character, else the last one.
-- RXP.functions.next is not called on purpose: in some cases it loads the guide instead of returning it.
local nextGuideCache = { }
local function NextGuide( guide )
	local rxp = _G.RXP
	if type( guide.next ) ~= "string" or type( rxp.GetGuideTable ) ~= "function" or type( rxp.FetchGuide ) ~= "function" or type( rxp.ProcessGuideTable ) ~= "function" then
		return nil
	end

	local found
	for entry in string.gmatch( guide.next, "[^;]+" ) do
		local group, name = string.match( entry, "^%s*(.-)%s*\\%s*(.-)%s*$" )
		if not group then
			group, name = guide.group, string.trim( entry )
		end
		local ok, candidate = pcall( rxp.GetGuideTable, group, name )
		if ok and type( candidate ) == "table" then
			found = candidate
			local okActive, active = pcall( rxp.IsGuideActive or function( ) return true end, candidate )
			if okActive and active then break end
		end
	end
	if not found then return nil end

	local key = tostring( found.group ) .. "|" .. tostring( found.name )
	if nextGuideCache[key] == nil then
		local ok, processed = pcall( function( )
			local fetched = rxp:FetchGuide( found.group, found.name )
			return fetched and fetched.steps and rxp.ProcessGuideTable( fetched )
		end )
		nextGuideCache[key] = ok and type( processed ) == "table" and type( processed.steps ) == "table" and processed or false
	end
	return nextGuideCache[key] or nil
end

local function ReadStep( items, step, upcoming )
	if type( step.elements ) ~= "table" then return end
	for _, element in ipairs( step.elements ) do
		local read = READERS[element.tag]
		local stillNeeded = STILL_NEEDED[element.tag]
		if read and ( upcoming or ( stillNeeded and stillNeeded( element ) ) ) then
			local set = items[element.tag] or { }
			items[element.tag] = set
			read( element, set )
		end
	end
end

-- Items you were told to get for a quest you haven't turned in yet, e.g. bought at the auction house
-- for a quest that is only accepted a few guides later. Saved per character, because the guide with
-- the collect step is long gone by then: { [questID] = { [itemID] = tag } }
local function PendingQuests( )
	local db = _G.ArkInventoryRules_RestedXPCharDB
	if type( db ) ~= "table" then
		db = { }
		_G.ArkInventoryRules_RestedXPCharDB = db
	end
	if type( db.pendingQuests ) ~= "table" then
		db.pendingQuests = { }
	end
	return db.pendingQuests
end

local function RememberPending( step )
	if type( step.elements ) ~= "table" then return end
	local pending = PendingQuests( )
	for _, element in ipairs( step.elements ) do
		local questId = tonumber( element.questId )
		if STILL_NEEDED[element.tag] == collectQuestOpen and questId and questId > 0 and not QuestTurnedIn( questId ) then
			local set = { }
			READERS[element.tag]( element, set )
			pending[questId] = pending[questId] or { }
			for id in pairs( set ) do pending[questId][id] = element.tag end
		end
	end
end

local function Collect( )
	local items = { all = { } }
	local guide = RXPData( )
	if not guide then return items, "" end

	local current = tonumber( RXPCData and RXPCData.currentStep ) or 1
	local skipped = RXPCData and RXPCData.stepSkip or { }

	for index, step in ipairs( guide.steps ) do
		-- the current and all following steps, plus earlier steps that are still active (sticky)
		local upcoming = ( index >= current or step.active ) and not skipped[index]
		ReadStep( items, step, upcoming )
		if not upcoming and not skipped[index] then
			RememberPending( step )
		end
	end

	-- remembered items until their quest is turned in
	local pending = PendingQuests( )
	for questId, pendingItems in pairs( pending ) do
		if QuestTurnedIn( questId ) then
			pending[questId] = nil
		else
			for id, tag in pairs( pendingItems ) do
				items[tag] = items[tag] or { }
				items[tag][id] = true
			end
		end
	end

	-- every step of the following guides
	local guideNames = { tostring( guide.group ) .. "|" .. tostring( guide.name ) }
	local nextGuide = guide
	for _ = 1, NEXT_GUIDES do
		nextGuide = NextGuide( nextGuide )
		if not nextGuide then break end
		guideNames[#guideNames + 1] = tostring( nextGuide.name )
		for _, step in ipairs( nextGuide.steps ) do
			ReadStep( items, step, true )
		end
	end

	for tag, set in pairs( items ) do
		if tag ~= "all" then
			for id in pairs( set ) do items.all[id] = true end
		end
	end

	-- signature to notice when the result changes
	local ids = { }
	for id in pairs( items.all ) do ids[#ids + 1] = id end
	table.sort( ids )
	return items, table.concat( guideNames, "|" ) .. "|" .. table.concat( ids, "," )
end

local function ItemID( )
	local obj = ArkInventoryRules.Object
	if not obj.h or obj.class ~= "item" then return nil end
	local id = obj.info and obj.info.osd and tonumber( obj.info.osd.id )
	return id or tonumber( string.match( obj.h, "item:(%d+)" ) )
end

-- rxpitem( ) : item is used by a remaining step of the current RestedXP guide
-- rxpitem( "use", "collect", ... ) : only for these guide commands
function rule.rxpitem( ... )
	local id = ItemID( )
	if not id then return false end

	local ac = select( "#", ... )
	if ac == 0 then
		return guideItems.all[id] == true
	end
	for ax = 1, ac do
		local tag = select( ax, ... )
		if type( tag ) ~= "string" then
			error( string.format( ArkInventory.Localise["RULE_FAILED_ARGUMENT_IS_NOT"], "rxpitem", ax, ArkInventory.Localise["STRING"] ), 0 )
		end
		local set = guideItems[string.lower( string.trim( tag ) )]
		if set and set[id] then return true end
	end
	return false
end

-- recompute after step changes; only redraw the bags when the item list really changed
local refreshPending = false
local function Refresh( )
	if refreshPending then return end
	refreshPending = true
	C_Timer.After( 1, function( )
		refreshPending = false
		local items, key = Collect( )
		guideItems = items
		if key ~= guideKey then
			guideKey = key
			ArkInventory.ItemCacheClear( )
			ArkInventory.Frame_Main_Generate( nil, ArkInventory.Const.Window.Draw.Recalculate )
		end
	end )
end

-- cheap check for guide or step changes; some RestedXP code keeps its own reference to SetStep,
-- so a hook alone would miss changes
local lastState
local function CheckState( )
	local guide = RXPData( )
	local state = guide and string.format( "%s|%s|%s", tostring( guide.group ), tostring( guide.name ), tostring( RXPCData and RXPCData.currentStep ) ) or ""
	if state ~= lastState then
		lastState = state
		Refresh( )
	end
end

local hooked = false
function rule:OnEnable( )
	ArkInventoryRules.Register( self, "rxpitem", rule.rxpitem )
	if not hooked then
		hooked = true
		C_Timer.NewTicker( 2, CheckState )
		CheckState( )
		-- accepting, turning in or abandoning a quest changes which earlier items still count
		local f = CreateFrame( "Frame" )
		for _, event in ipairs( { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" } ) do
			pcall( f.RegisterEvent, f, event )
		end
		f:SetScript( "OnEvent", Refresh )
	end
end
