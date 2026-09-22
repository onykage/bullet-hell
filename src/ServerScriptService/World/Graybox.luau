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

function Graybox.part(options: PartOptions): Part
	local part = Instance.new("Part")
	part.Name = options.name
	part.Size = options.size
	part.CFrame = options.cframe or CFrame.new()
	part.Color = options.color or Color3.fromRGB(120, 120, 128)
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Anchored = if options.anchored ~= nil then options.anchored else true
	part.CanCollide = if options.canCollide ~= nil then options.canCollide else true
	part.Transparency = options.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = options.shape or Enum.PartType.Block
	part.CollisionGroup = options.collisionGroup or Contract.CollisionGroups.WorldProp
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
	pad.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
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
