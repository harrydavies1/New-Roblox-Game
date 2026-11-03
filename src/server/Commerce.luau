--!nonstrict
local MarketplaceService=game:GetService("MarketplaceService")
local Players=game:GetService("Players")
local Commerce={}; Commerce.__index=Commerce
function Commerce.new(config,settings,store,engine,sandbox,callbacks)
 local self=setmetatable({Config=config,Store=store,Engine=engine,Settings=settings,Sandbox=sandbox,Catalog={},ProductsById={},PassesById={},Owned={},LastPrompt={},LoadingPasses={}},Commerce)
 for _,group in {{Items=config.Products,Ids=settings.ProductIds,Map=self.ProductsById},{Items=config.Passes,Ids=settings.PassIds,Map=self.PassesById}} do
  for _,item in group.Items do
   local id=group.Ids[item.Key]
   if type(id)=="number" and id>0 and id%1==0 then assert(not group.Map[id],"Duplicate shop ID"); group.Map[id]=item.Key end
  end
 end
 MarketplaceService.ProcessReceipt=function(receipt)
  if sandbox then return Enum.ProductPurchaseDecision.NotProcessedYet end
  local key=self.ProductsById[receipt.ProductId]; local player=Players:GetPlayerByUserId(receipt.PlayerId)
  if not key or not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
  local committed,reason=store:CompletePurchase(receipt.PlayerId,receipt.PurchaseId,function(p) return engine:GrantProduct(p,key,os.time()) end)
  if not committed then warn("MOG receipt deferred",reason); return Enum.ProductPurchaseDecision.NotProcessedYet end
  if reason~="duplicate" then callbacks.Purchased(player,key) end
  return Enum.ProductPurchaseDecision.PurchaseGranted
 end
 MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
  if purchased and self.PassesById[id] then task.spawn(function()
   for _=1,3 do
    if not player.Parent then return end
    self:RefreshPasses(player); if self:GetPasses(player)[self.PassesById[id]] then break end; task.wait(1)
   end
   callbacks.Changed(player)
  end) end
 end)
 task.spawn(function()
  for _,group in {{Items=config.Products,Ids=settings.ProductIds,Kind="Product",Type=Enum.InfoType.Product},{Items=config.Passes,Ids=settings.PassIds,Kind="Pass",Type=Enum.InfoType.GamePass}} do
   for _,item in group.Items do
    local id=group.Ids[item.Key] or 0; local offer={Id=id,Kind=group.Kind,Enabled=false,Price=0}; self.Catalog[item.Key]=offer
    if id>0 and not sandbox then
     local ok,info=pcall(MarketplaceService.GetProductInfo,MarketplaceService,id,group.Type)
     if ok and type(info.PriceInRobux)=="number" and info.PriceInRobux>0 and info.IsForSale~=false then offer.Price=info.PriceInRobux; offer.Enabled=true end
    end
   end
  end
  callbacks.CatalogReady()
 end)
 return self
end
function Commerce:GetPasses(player) return self.Owned[player.UserId] or {} end
function Commerce:RefreshPasses(player)
 if self.LoadingPasses[player.UserId] then return end
 self.LoadingPasses[player.UserId]=true; local owned=self.Owned[player.UserId] or {}
 if not self.Sandbox then
  for id,key in self.PassesById do local ok,value=pcall(MarketplaceService.UserOwnsGamePassAsync,MarketplaceService,player.UserId,id); if ok then owned[key]=value==true end end
 end
 if player.Parent then self.Owned[player.UserId]=owned end
 self.LoadingPasses[player.UserId]=nil
end
function Commerce:Prompt(player,key)
 local offer=if type(key)=="string" then self.Catalog[key] else nil
 if not offer or not offer.Enabled or self.Sandbox then return false,"This purchase is unavailable." end
 if offer.Kind=="Pass" and self:GetPasses(player)[key] then return false,"You already own this pass." end
 if offer.Kind=="Product" then
  local p=self.Store:Get(player.UserId); local product=self.Engine.Products[key]
  if not p or not product or (product.Kind~="Boost" and p[product.Currency]+product.Amount>self.Config.MaxCurrency) then return false,"Spend some currency before purchasing another pack." end
 end
 local now=os.clock(); if now-(self.LastPrompt[player.UserId] or -100)<3 then return false,"Please finish the current purchase window." end
 self.LastPrompt[player.UserId]=now
 local ok=pcall(function()
  if offer.Kind=="Product" then MarketplaceService:PromptProductPurchase(player,offer.Id) else MarketplaceService:PromptGamePassPurchase(player,offer.Id) end
 end)
 return ok,if ok then "Roblox shows the final price before you confirm." else "Roblox couldn't open the purchase window."
end
function Commerce:Forget(player) self.Owned[player.UserId]=nil; self.LastPrompt[player.UserId]=nil end
return Commerce
