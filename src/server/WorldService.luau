--!nonstrict
local CollectionService = game:GetService("CollectionService")
local WorldService = {}
WorldService.__index = WorldService
function WorldService.new(config, callbacks)
 local self = setmetatable({Map = workspace:WaitForChild("MogWorld")},WorldService)
 for _, world in config.Worlds do
  local island = self.Map:WaitForChild(world.Id)
  for _, crystal in island.Shards:GetChildren() do
   crystal:SetAttribute("CrystalId",world.Id.."/"..crystal.Name)
   CollectionService:AddTag(crystal,"MogCrystal")
   local prompt=Instance.new("ProximityPrompt"); prompt.Name="CollectPrompt"; prompt.ActionText="Collect Aura"
   prompt.ObjectText=if crystal.Name:sub(1,5)=="Bonus" then "Sky crystal • 100× Mog Power" else "Aura crystal • 30× Mog Power"
   prompt.MaxActivationDistance=9; prompt.RequiresLineOfSight=false; prompt.Parent=crystal
   prompt.Triggered:Connect(function(player) if self:IsNear(player,crystal,12) then callbacks.Collect(player,world.Id,crystal) end end)
  end
  for _, gate in island.Portals:GetChildren() do
   local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Explore island"; prompt.ObjectText=gate.Name
   for _, target in config.Worlds do if target.Id==gate.Name then prompt.ObjectText=target.Name end end
   prompt.MaxActivationDistance=12; prompt.RequiresLineOfSight=false; prompt.Parent=gate
   prompt.Triggered:Connect(function(player) if self:IsNear(player,gate,15) then callbacks.Portal(player,gate.Name) end end)
  end
  for key,panel in {PetShop="Pets",Quests="Goals",Rebirth="Upgrades"} do
   local marker=island.Markers:FindFirstChild(key)
   if marker then
    local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Open "..panel; prompt.ObjectText="MOG MODE"
    prompt.MaxActivationDistance=12; prompt.RequiresLineOfSight=false; prompt.Parent=marker
    prompt.Triggered:Connect(function(player) if self:IsNear(player,marker,15) then callbacks.OpenPanel(player,panel) end end)
   end
  end
 end
 local spawn=Instance.new("SpawnLocation"); spawn.Name="MogSpawn"; spawn.Anchored=true; spawn.Neutral=true
 spawn.Size=Vector3.new(10,1,10); spawn.Transparency=1; spawn.CanCollide=false; spawn.Duration=2
 spawn.CFrame=CFrame.new(0,6,29); spawn.Parent=workspace
 return self
end
function WorldService:IsNear(player,part,distance)
 local c=player.Character; local root=c and c:FindFirstChild("HumanoidRootPart"); local humanoid=c and c:FindFirstChildOfClass("Humanoid")
 return root and humanoid and humanoid.Health>0 and (root.Position-part.Position).Magnitude<=distance
end
function WorldService:Teleport(player,id)
 local world=self.Map:FindFirstChild(id); local c=player.Character
 local root=c and c:FindFirstChild("HumanoidRootPart"); local humanoid=c and c:FindFirstChildOfClass("Humanoid")
 if not world or not root or not humanoid or humanoid.Health<=0 then return false end
 local p=world.Markers.Spawn.Position+Vector3.new(0,4,0)
 c:PivotTo(CFrame.lookAt(p,p+Vector3.new(0,0,-25))); root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
 return true
end
return WorldService
