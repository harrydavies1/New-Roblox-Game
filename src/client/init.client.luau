--!nonstrict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local shared=ReplicatedStorage:WaitForChild("MogShared")
local Config=require(shared.Config)
local Engine=require(shared.Economy).new(Config)
local Format=require(shared.Format)
local Factory=require(script.PetFactory)
local UI=require(script.UI)
local Effects=require(script.Effects)
local Pose=require(script.MogPose)
local Audio=require(script.Audio)
local WorldVisibility=require(script.WorldVisibility)
local CourseGuide=require(script.CourseGuide)
local remotes=ReplicatedStorage:WaitForChild("MogRemotes")
local request=remotes:WaitForChild("Action"); local click=remotes:WaitForChild("Click")
local stateEvent=remotes:WaitForChild("State"); local effectEvent=remotes:WaitForChild("Effect")
local ui,effects,visibility,accept; local lastClick=-1
ui=UI.new(Config,Engine,Format,{
 Click=function()
  if not ui or not ui.State or ui.ConfirmFrame.Visible then return end
  local now=os.clock(); if now-lastClick<Config.ClickCooldown then return end; lastClick=now
  click:FireServer(); ui:Pulse(); if effects then effects:Sound("Click") end
 end,
 Action=function(name,payload) return request:InvokeServer(name,payload) end,
 Feedback=function(kind) if effects then effects:Sound(kind) end end,
 State=function(state) if accept then accept(state) end end,
 PetPreview=function(viewport,definition,level)
  local pet=Factory.Create(definition,level); local world=Instance.new("WorldModel"); world.Parent=viewport; pet.Model.Parent=world
  local camera=Instance.new("Camera"); camera.FieldOfView=38; camera.CFrame=CFrame.lookAt(Vector3.new(3.2,2,-5),Vector3.new(0,.3,0)); camera.Parent=viewport; viewport.CurrentCamera=camera
 end,
})
local audio=Audio.new(function() return if ui.State then ui.State.Settings else {SFX=true,Effects=true} end)
effects=Effects.new(Config,Engine,Format,Factory,ui,audio)
effects.Pose=Pose.new(function() return ui.State and ui.State.Settings.Effects end)
visibility=WorldVisibility.new(Engine.Worlds)
effects.Guide=CourseGuide.new(Config,Engine,function() return ui.State end)
accept=function(state)
 if type(state)~="table" then return end; local old=ui.State
 if not old or old.CurrentWorld~=state.CurrentWorld then ui.PetWorld=state.CurrentWorld; ui.CourseWorld=state.CurrentWorld; ui.SelectedCourse=nil end
 ui:Update(state)
 visibility:SetWorld(state.CurrentWorld)
 if old and state.Level>old.Level then effects:Celebrate(); task.delay(.15,function() effects:Sound("Level") end); ui:Toast("LEVEL "..state.Level.." • "..Engine:Rank(state.Level)) end
end
stateEvent.OnClientEvent:Connect(accept)
effectEvent.OnClientEvent:Connect(function(event) if type(event)=="table" then effects:Handle(event) end end)
task.spawn(function()
 for _=1,15 do
  if ui.State then return end
  local ok,result=pcall(request.InvokeServer,request,"GetState",{}); if ok and result and result.State then accept(result.State); return end; task.wait(2)
 end
 ui:Toast("Your save is taking longer than usual. Please rejoin if loading doesn't finish.",false)
end)
task.spawn(function()
 while Players.LocalPlayer.Parent do
  task.wait(15); local ok,result=pcall(request.InvokeServer,request,"GetState",{}); if ok and result and result.State then accept(result.State) end
 end
end)
