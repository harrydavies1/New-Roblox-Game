--!nonstrict
-- Explicit service-boundary fake; this does not emulate Roblox rendering/physics.
local function signal()
 local callbacks={}
 return {
  Connect=function(_,f) table.insert(callbacks,f); return {Disconnect=function() local i=table.find(callbacks,f); if i then table.remove(callbacks,i) end end} end,
  Fire=function(_,...) for _,f in table.clone(callbacks) do f(...) end end,
 }
end
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2={new=function(xs,xo,ys,yo) return {X=UDim.new(xs or 0,xo or 0),Y=UDim.new(ys or 0,yo or 0)} end}
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
local Vector2={new=function(x,y) return {X=x,Y=y} end}; Vector2.zero=Vector2.new(0,0)
local vectorMeta={}; local Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end}
vectorMeta.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__index=function(v,key) if key=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end; return nil end
Vector3.zero=Vector3.new(0,0,0)
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end,fromHex=function(s) return {R=tonumber(s:sub(1,2),16)/255,G=tonumber(s:sub(3,4),16)/255,B=tonumber(s:sub(5,6),16)/255} end}
local cfMeta={}; local CFrame={new=function(x,y,z) return setmetatable({Position=if type(x)=="table" then x else Vector3.new(x or 0,y or 0,z or 0)},cfMeta) end}
cfMeta.__mul=function(a,b) return CFrame.new(a.Position+b.Position) end
CFrame.identity=CFrame.new(0,0,0); CFrame.Angles=function() return CFrame.new(0,0,0) end; CFrame.lookAt=function(p,_target) return CFrame.new(p) end
local Enum=setmetatable({},{__index=function(self,key)
 local e=setmetatable({},{__index=function(_,v) return key.."."..v end}); rawset(self,key,e); return e
end})
local ColorSequence={new=function(...) return {...} end}
local TweenInfo={new=function(...) return {...} end}
local bools={Active=true,Interactable=true,Visible=true,AutoButtonColor=true,ResetOnSpawn=true,IgnoreGuiInset=true,TextWrapped=true,TextScaled=true,Anchored=true,CanCollide=true,CanTouch=true,CanQuery=true,CastShadow=true,Enabled=true}
local guis={Frame=true,ScrollingFrame=true,TextButton=true,TextLabel=true,ViewportFrame=true}
local methods={}
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants() local out={}; local function walk(node) for _,c in node._children do table.insert(out,c); walk(c) end end; walk(self); return out end
function methods:IsA(class) return self.ClassName==class or (class=="GuiObject" and guis[self.ClassName]==true) or (class=="BasePart" and self.ClassName=="Part") end
function methods:FindFirstChild(name) for _,c in self._children do if c.Name==name then return c end end; return nil end
function methods:FindFirstChildOfClass(class) for _,c in self._children do if c.ClassName==class then return c end end; return nil end
function methods:WaitForChild(name) local c=self:FindFirstChild(name); assert(c,"Missing fake child "..name); return c end
function methods:Destroy() for _,c in self:GetChildren() do c:Destroy() end; self.Parent=nil end
function methods:GetPropertyChangedSignal(key) if not self._signals[key] then self._signals[key]=signal() end; return self._signals[key] end
function methods:SetAttribute(key,value) self._attributes[key]=value end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:PivotTo(cf) local root=self:FindFirstChild("HumanoidRootPart"); if root then root.CFrame=cf; root.Position=cf.Position end end
function methods:RequestStreamAroundAsync(point, timeout)
 self._streamRequests = self._streamRequests or {}
 table.insert(self._streamRequests, {Point=point, Timeout=timeout, Anchored=self.Character and self.Character.HumanoidRootPart.Anchored})
end
function methods:FindFirstAncestorOfClass(class)
 local parent=self.Parent
 while parent do if parent.ClassName==class then return parent end; parent=parent.Parent end
 return nil
end
function methods:Play() self.Playing=true end
function methods:Stop() self.Playing=false end
function methods:FireClient(player,data)
 self._events=self._events or {}; table.insert(self._events,{Player=player,Data=data})
end
function methods:FireAllClients(data)
 self._broadcasts=self._broadcasts or {}; table.insert(self._broadcasts,data)
end
function methods:Kick(message) self.KickReason=message end
local meta={
 __index=function(self,key) if methods[key] then return methods[key] end; local v=self._props[key]; if v~=nil then return v end; return methods.FindFirstChild(self,key) end,
 __newindex=function(self,key,value)
  if bools[key] then assert(type(value)=="boolean",self.ClassName.."."..key.." requires boolean") end
  if key=="Text" then assert(type(value)=="string","Text must be a string") end
  if key=="Parent" then local old=self._props.Parent; if old then local i=table.find(old._children,self); if i then table.remove(old._children,i) end end; if value then table.insert(value._children,self) end end
  self._props[key]=value
 end,
}
local Instance={new=function(class) return setmetatable({_children={},_signals={},_attributes={},_props={ClassName=class,Name=class,Active=true,Interactable=true,Visible=true,Enabled=true,Position=UDim2.new(),Size=UDim2.new(),Text="",Activated=signal(),Triggered=signal(),Touched=signal(),InputBegan=signal(),OnServerEvent=signal(),CharacterAdded=signal(),PlayerAdded=signal(),PlayerRemoving=signal(),DescendantAdded=signal(),DescendantRemoving=signal()}},meta) end}
local player=Instance.new("Player"); local gui=Instance.new("PlayerGui"); gui.Name="PlayerGui"; gui.Parent=player
local camera=Instance.new("Camera"); camera.ViewportSize=Vector2.new(1280,720)
local workspace=Instance.new("Workspace"); workspace.CurrentCamera=camera
local services={Players={LocalPlayer=player},RunService={Heartbeat=signal()},UserInputService={InputBegan=signal(),GamepadEnabled=false},GuiService={GetGuiInset=function() return Vector2.new(0,36),Vector2.zero end},TweenService={Create=function(_,object,_,values) return {Play=function() for k,v in values do object[k]=v end end} end}}
local game={JobId="contract-test",GetService=function(_,name) assert(services[name],"Unmocked service "..name); return services[name] end}
local task={delay=function() end,spawn=function(f) f() end,wait=function() end}
