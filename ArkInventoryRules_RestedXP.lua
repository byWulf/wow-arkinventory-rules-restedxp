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

local function Collect( )
	local items = { all = { } }
	local guide = RXPData( )
	if not guide then return items, "" end

	local current = tonumber( RXPCData and RXPCData.currentStep ) or 1
	local skipped = RXPCData and RXPCData.stepSkip or { }

	for index, step in ipairs( guide.steps ) do
		-- the current and all following steps, plus earlier steps that are still active (sticky)
		if ( index >= current or step.active ) and not skipped[index] and type( step.elements ) == "table" then
			for _, element in ipairs( step.elements ) do
				local read = READERS[element.tag]
				if read then
					local set = items[element.tag] or { }
					items[element.tag] = set
					read( element, set )
				end
			end
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
	return items, tostring( guide.group ) .. "|" .. tostring( guide.name ) .. "|" .. table.concat( ids, "," )
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
	end
end
