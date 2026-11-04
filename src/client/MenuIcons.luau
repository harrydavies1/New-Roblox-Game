--!nonstrict
-- Original little menu illustrations, drawn from GUI shapes. No image uploads.
local Icons = {}
function Icons.draw(parent, kind, color, ink)
	local function shape(name, x, y, w, h, fill, radius, rotation)
		local p = Instance.new("Frame"); p.Name = name
		p.Position = UDim2.fromScale(x, y); p.Size = UDim2.fromScale(w, h)
		p.BackgroundColor3 = fill; p.BorderSizePixel = 0; p.Rotation = rotation or 0; p.Parent = parent
		if radius then local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(radius, 0); c.Parent = p end
		return p
	end
	local white = Color3.fromRGB(255, 251, 231)
	if kind == "Obbies" then
		shape("LowStep", .06, .69, .28, .22, ink, .12)
		shape("MiddleStep", .32, .46, .28, .45, ink, .12)
		shape("HighStep", .59, .22, .31, .69, ink, .1)
		shape("StepShine", .64, .26, .21, .08, color, .2)
		shape("FlagPole", .66, .02, .045, .25, ink, .1)
		shape("VictoryFlag", .70, .02, .23, .15, color, .1, -8)
	elseif kind == "Pets" or kind == "Mascot" then
		shape("LeftEar", .10, .02, .27, .34, ink, .1, -19)
		shape("RightEar", .64, .02, .27, .34, ink, .1, 19)
		shape("Head", .07, .17, .87, .71, ink, .26)
		shape("Face", .12, .22, .77, .59, color, .28)
		for _, x in { .20, .56 } do
			shape("Shade", x, .37, .26, .22, ink, .2)
			shape("LensGlint", x+.035, .40, .08, .035, white, .2, -15)
		end
		shape("Bridge", .44, .40, .16, .055, ink, .1)
		shape("Smirk", .37, .69, .29, .035, ink, .1, -5)
	elseif kind == "Upgrades" then
		shape("Bar", .19, .43, .62, .13, ink, .25, -18)
		for _, x in { .09, .70 } do
			shape("Weight", x, .21, .21, .57, ink, .2, -18)
			shape("PlateInset", x+.04, .26, .10, .38, color, .2, -18)
		end
		shape("PowerSpark", .60, .05, .12, .12, color, .12, 45)
	elseif kind == "Worlds" then
		shape("PlanetRim", .13, .11, .73, .73, ink, .5)
		shape("Planet", .20, .18, .59, .59, color, .5)
		shape("Land", .32, .22, .30, .23, white, .35, 20)
		shape("Island", .45, .56, .20, .14, ink, .35, -12)
		shape("Orbit", .01, .49, .99, .10, ink, .4, -26)
		shape("OrbitShine", .07, .49, .38, .035, white, .4, -26)
	elseif kind == "Goals" then
		shape("Calendar", .10, .14, .80, .75, ink, .13)
		shape("Page", .17, .36, .66, .45, white, .1)
		shape("Header", .17, .21, .66, .14, color, .1)
		for _, x in { .29, .65 } do shape("Binding", x, .04, .07, .25, ink, .4) end
		shape("CheckShort", .30, .54, .16, .09, ink, .2, 43)
		shape("CheckLong", .42, .50, .30, .09, ink, .2, -43)
	elseif kind == "Shop" then
		shape("Bag", .14, .32, .72, .58, ink, .15)
		shape("BagFront", .21, .39, .58, .44, color, .14)
		shape("HandleOuter", .31, .08, .38, .43, ink, .4)
		shape("HandleHole", .38, .15, .24, .27, white, .4)
		shape("BagLip", .14, .32, .72, .12, ink, .1)
		shape("Diamond", .41, .55, .20, .20, ink, .1, 45)
	elseif kind == "Settings" then
		for i = 0, 3 do shape("GearTooth", .37, .02, .26, .96, ink, .13, i*45) end
		shape("Gear", .16, .16, .68, .68, ink, .5)
		shape("GearFace", .25, .25, .50, .50, color, .5)
		shape("GearCenter", .39, .39, .22, .22, ink, .5)
	end
end
return Icons
