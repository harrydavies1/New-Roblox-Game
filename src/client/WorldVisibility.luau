--!nonstrict
-- Hide retained streamed islands explicitly; distant old scenery must stay invisible.
local WorldVisibility = {}
function WorldVisibility.new(worlds)
	local map = workspace:WaitForChild("MogWorld")
	local self = { Current = nil, WorldOf = {} }
	local function apply(object, id)
		local visible = id == self.Current
		if object:IsA("BasePart") then object.LocalTransparencyModifier = if visible then 0 else 1
		elseif object:IsA("BillboardGui") or object:IsA("ProximityPrompt") or object:IsA("ParticleEmitter") then object.Enabled = visible end
	end
	local function register(object)
		local parent = object
		while parent and parent.Parent ~= map do parent = parent.Parent end
		if parent and worlds[parent.Name] then self.WorldOf[object] = parent.Name; apply(object, parent.Name) end
	end
	for _, object in map:GetDescendants() do register(object) end
	map.DescendantAdded:Connect(register)
	map.DescendantRemoving:Connect(function(object) self.WorldOf[object] = nil end)
	function self:SetWorld(id)
		if id == self.Current then return end
		self.Current = id
		for object, world in self.WorldOf do if object.Parent then apply(object, world) end end
	end
	return self
end
return WorldVisibility
