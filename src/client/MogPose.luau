--!nonstrict
local RunService=game:GetService("RunService")
local MogPose={}
function MogPose.new(isEnabled)
 local self={Active={}}
 local function restore(state) for _,j in state.Joints do if j.Motor.Parent then j.Motor.C0=j.Base end end end
 function self:Play(player)
  if not isEnabled() or not player.Character then return end
  if self.Active[player] then restore(self.Active[player]) end
  local state={Start=os.clock(),Character=player.Character,Joints={}}
  for _,motor in player.Character:GetDescendants() do
   if not motor:IsA("Motor6D") then continue end
   local name=motor.Name; local angle
   if name=="RightShoulder" or name=="Right Shoulder" then angle=Vector3.new(-.1,0,-.9)
   elseif name=="LeftShoulder" or name=="Left Shoulder" then angle=Vector3.new(-.1,0,.9)
   elseif name=="RightElbow" or name=="LeftElbow" then angle=Vector3.new(-.8,0,0)
   elseif name=="Waist" then angle=Vector3.new(-.08,0,0)
   elseif name=="Neck" then angle=Vector3.new(.08,.1,0) end
   if angle then table.insert(state.Joints,{Motor=motor,Base=motor.C0,Angle=angle}) end
  end
  self.Active[player]=state
 end
 RunService.PreSimulation:Connect(function()
  local now=os.clock()
  for player,state in self.Active do
   local t=(now-state.Start)/.8
   if t>=1 or not state.Character.Parent or player.Character~=state.Character or not isEnabled() then restore(state); self.Active[player]=nil; continue end
   local weight=math.sin(t*math.pi)^.7
   for _,j in state.Joints do if j.Motor.Parent then j.Motor.C0=j.Base*CFrame.Angles(j.Angle.X*weight,j.Angle.Y*weight,j.Angle.Z*weight) end end
  end
 end)
 return self
end
return MogPose
