--!strict
--[[
	World/Graybox.luau

	Primitive-construction helpers for the code-generated blockout.

	This module exists so that milestone 1 is playable before the Studio
	workstream delivers any geometry. Everything it builds is tagged and
	attributed exactly as authored content would be (see Shared/Contract), so
	when real geometry arrives the generator is switched off and nothing
	downstream changes: services find their markers by tag either way.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local Graybox = {}

-- Collision-group failures are warned about once each, not once per part.
Graybox._warnedGroups = {} :: { [string]: boolean }

export type PartOptions = {
	name: string,
	size: Vector3,
	cfrag: CFrame?,
	cframe: CFrame?,
	color: Color3?,
	material: Enum.Material?,
	anchored: boolean?,
	canCollide: boolean?,
	transparency: number?,
	collisionGroup: string?,
	parent: Instance?,
	shape: Enum.PartType?,
}

--[[
	Places a part and keeps Position in step with CFrame.

	Assigning Position after CFrame is a no-op in Roblox — Position is a view of
	CFrame's translation, and setting it preserves rotation. It is written
	explicitly because the headless harness (tests/headless) runs on Lune, which
	stores the two properties independently, so every `.Position` read in the
	world code would otherwise see an unset property there.
]]
local function place(part: BasePart, cframe: CFrame)
	part.CFrame = cframe
	part.Position = cframe.Position
end

Graybox.place = place

function Graybox.part(options: PartOptions): Part
	local part = Instance.new("Part")
	part.Name = options.name
	part.Size = options.size
	part.Color = options.color or Color3.fromRGB(120, 120, 128)
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Anchored = if options.anchored ~= nil then options.anchored else true
	part.CanCollide = if options.canCollide ~= nil then options.canCollide else true
	part.Transparency = options.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = options.shape or Enum.PartType.Block
	-- Assigning a collision group that failed to register throws, and this is
	-- the single chokepoint every piece of world geometry passes through. A
	-- part in the wrong collision group is a bug; a world with no floor because
	-- of one is a catastrophe. The group is best-effort, the part is not.
	local group = options.collisionGroup or Contract.CollisionGroups.WorldProp
	local grouped = pcall(function()
		part.CollisionGroup = group
	end)
	if not grouped and not Graybox._warnedGroups[group] then
		Graybox._warnedGroups[group] = true
		warn(`[Graybox] collision group "{group}" is unavailable; parts will use Default`)
	end

	place(part, options.cframe or CFrame.new())
	part.Parent = options.parent
	return part
end

--[[
	Tags an Instance and stamps the attributes the contract requires for that
	tag. Asserts if a required attribute was not supplied, which turns a
	contract violation into a startup failure rather than a runtime mystery.
]]
function Graybox.mark(instance: Instance, tag: string, contentId: string, attributes: { [string]: any }?)
	instance:SetAttribute(Contract.ContentIdAttribute, contentId)

	for key, value in attributes or {} do
		instance:SetAttribute(key, value)
	end

	CollectionService:AddTag(instance, tag)

	local ok, reason = Contract.validateInstance(instance, tag)
	assert(ok, `[Graybox] {reason}`)
end

--[[
	An invisible, non-colliding volume. Zone volumes and spawn volumes are
	regions, not obstacles.
]]
function Graybox.volume(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Graybox.part({
		name = name,
		size = size,
		cframe = cframe,
		anchored = true,
		canCollide = false,
		transparency = 1,
		parent = parent,
	})
	part.CastShadow = false
	return part
end

--[[
	A flat visual marker on the floor. Used for arena entrances and spawn pads
	so players can see the gameplay object the tag describes (§17.3: the world
	should communicate before the map does).
]]
function Graybox.pad(name: string, radius: number, cframe: CFrame, color: Color3, parent: Instance): Part
	local pad = Graybox.part({
		name = name,
		size = Vector3.new(radius * 2, 0.4, radius * 2),
		cframe = cframe,
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = parent,
		shape = Enum.PartType.Cylinder,
	})
	-- Cylinder parts extend along X; stand it up to lie flat on the floor.
	pad.Size = Vector3.new(0.4, radius * 2, radius * 2)
	place(pad, cframe * CFrame.Angles(0, 0, math.rad(90)))
	return pad
end

function Graybox.label(text: string, adornee: BasePart, offsetY: number, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GrayboxLabel"
	billboard.Size = UDim2.fromScale(14, 2.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 320
	billboard.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = billboard

	billboard.Parent = adornee
end

--[[
	Ring of positions on the XZ plane. Used for arena walls, cover, conductors,
	spawns — anything radially arranged around a centre.
]]
function Graybox.ring(center: Vector3, radius: number, count: number, startDegrees: number?): { CFrame }
	local frames = table.create(count)
	local offset = startDegrees or 0

	for index = 0, count - 1 do
		local angle = math.rad(offset + (index / count) * 360)
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		frames[index + 1] = CFrame.lookAt(position, center)
	end

	return frames
end

--[[
	Builds a closed ring of wall segments around a centre.

	Segment width is DERIVED from the radius and count rather than passed in,
	which is the whole point: the original arena walls were a fixed 22 studs
	wide on a ring whose chord length nobody recomputed after the radius
	changed, so the hub ended up with four open corners and players walked
	straight out into the void.

	chord = 2 * r * sin(pi / count), then an overlap factor on top. A ring built
	this way cannot have a gap.
]]
export type RingOptions = {
	center: Vector3,
	radius: number,
	height: number,
	thickness: number,
	segments: number,
	color: Color3?,
	material: Enum.Material?,
	name: string?,
	parent: Instance,
	transparency: number?,
	-- An optional doorway. Segments whose centre falls within `gapWidth`
	-- degrees of `gapCenter` are omitted. Building the gap into the ring keeps
	-- the seal and the opening described in one place; cutting one afterwards
	-- leaves the ring briefly wrong with nothing to check it again.
	gapCenter: number?,
	gapWidth: number?,
}

function Graybox.sealedRing(options: RingOptions): { Part }
	local segments = math.max(3, options.segments)
	local chord = 2 * options.radius * math.sin(math.pi / segments)
	-- 1.2 covers the chord plus enough overlap that adjacent boxes intersect
	-- rather than merely touching at their corners.
	local width = chord * 1.2

	local gapCenter = options.gapCenter
	local gapWidth = options.gapWidth or 0

	local parts = {}
	for index = 0, segments - 1 do
		local degrees = (index / segments) * 360

		if gapCenter and gapWidth > 0 then
			local delta = math.abs((degrees - gapCenter) % 360)
			delta = math.min(delta, 360 - delta)
			if delta < gapWidth * 0.5 then
				continue
			end
		end

		local angle = math.rad(degrees)
		local offset = Vector3.new(math.cos(angle) * options.radius, 0, math.sin(angle) * options.radius)
		local frame = CFrame.lookAt(options.center + offset, options.center)
			* CFrame.new(0, options.height * 0.5, 0)

		table.insert(
			parts,
			Graybox.part({
				name = options.name or "Wall",
				size = Vector3.new(width, options.height, options.thickness),
				cframe = frame,
				color = options.color,
				material = options.material,
				transparency = options.transparency,
				parent = options.parent,
			})
		)
	end

	return parts
end

--[[
	An invisible, collidable barrier. Used for arena ceilings and the outer
	perimeter: geometry the player must not pass but should not see.
]]
function Graybox.barrier(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Graybox.part({
		name = name,
		size = size,
		cframe = cframe,
		anchored = true,
		canCollide = true,
		transparency = 1,
		parent = parent,
	})
	part.CastShadow = false
	-- Invisible to raycasts as well as to the eye, so bullets are not stopped
	-- by a wall the player cannot see.
	part.CanQuery = false
	return part
end

--[[
	A decorative surface laid flush over the real collision floor.

	These carry no collision and no raycast presence at all: the single bedrock
	slab underneath is the only thing anything stands on or casts against. That
	removes every seam, lip, and one-stud gap between adjacent floor pieces —
	the class of bug that makes players fall through a world.
]]
function Graybox.surface(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Graybox.part({
		name = name,
		size = size,
		cframe = cframe,
		color = color,
		material = material,
		canCollide = false,
		parent = parent,
	})
	part.CanQuery = false
	part.CanTouch = false
	return part
end

--[[
	Ensures a named Folder exists under a parent, creating it if absent.
	Idempotent: re-running the builder never duplicates containers.
]]
function Graybox.folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return Graybox
