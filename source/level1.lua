import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "shaker"

local gfx <const> = playdate.graphics

local lockSprite = nil
local legSprite = nil
local legLeftSprite = nil
local legRightSprite = nil

local kickSound = nil

local shaker = nil

function setupKickSound()
	kickSound = playdate.sound.sampleplayer.new("sounds/kick-metal")
end

function setupBackground()
	local bgImg = gfx.image.new("images/bg")
	assert(bgImg)
	
	gfx.sprite.setBackgroundDrawingCallback(
		function(x,y,width,height)
			gfx.setClipRect(x,y,width,height)
			bgImg:draw(0,142)
			gfx.clearClipRect()
		end
	)
end

function setupLockSprite()
	local lockImage = gfx.image.new("images/vending")
	assert(lockImage)
	
	lockSprite = gfx.sprite.new(lockImage)
	lockSprite:moveTo(200,120)
	lockSprite:add()
end

function setupLegsSprite()
	legLeftSprite = gfx.sprite.new(gfx.image.new("Images/legLeft"))
	legLeftSprite:moveTo(285,190)
	legRightSprite = gfx.sprite.new(gfx.image.new("Images/legRight"))
	legRightSprite:moveTo(117,190)
end

function setupShaker()
	playdate.startAccelerometer()
	shaker = Shaker.new(function()
	   print("THE PLAYDATE IS SHOOK!!")
	end, {sensitivity = Shaker.kSensitivitySim, threshold = 0.5, samples = 40})
	
	shaker:setEnabled(true)
end

function gameSetup()
	setupBackground()
	setupLockSprite()
	setupLegsSprite()
	
	-- setupShaker()
	setupKickSound()
end

local kicks = {}
local kLeft = 1
local kRight = 2

local alert = nil
local alertClearCallback = nil
local alertContinue = nil
local kAlertContinueContinue = 1
local kAlertContinueTryAgain = 2
local kAlertContinueNext = 3

local crankNeededDegrees = 0
local crankCompleteCallback = nil
local crankIndicatorShowing = false

local kStateShake = 0
local kStateKick = 1
local kStatePull = 2
local state = kStateKick

function drawLevelText()
	-- Ⓐ Ⓑ 🟨 ⊙ 🔒 🎣 ✛ ⬆️ ➡️ ⬇️ ⬅️
	gfx.drawText("*Level 1*", 20, 20)
	gfx.drawText("Get a\nfree Coke!", 20, 40)
	
	if alert then
		local sw = 400 -- screen width
		local sh = 240 -- screen height

		local w = 240
		local h = 100
		
		local x = sw/2 - w/2
		local y = sh/2 - h/2 + 20
		
		local r = 8 -- corner radius
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRoundRect(x,y,w,h,r)
		gfx.setColor(gfx.kColorBlack)
		gfx.setLineWidth(2)
		gfx.drawRoundRect(x,y,w,h,r)
		local m = 4 -- margin
		gfx.drawRoundRect(x+m,y+m,w-m*2,h-m*2,r/2)
		local p = 20 -- padding
		gfx.drawTextInRect(alert, x+p, y+p, w-p*2, h-p*2)
		if alertContinue == kAlertContinueContinue then
			gfx.drawText("Continue Ⓐ", x+142, y+h-p-8)
		elseif alertContinue == kAlertContinueTryAgain then
			gfx.drawText("Try Again Ⓐ", x+132, y+h-p-8)
		elseif alertContinue == kAlertContinueNext then
			gfx.drawText("Next Ⓐ", x+172, y+h-p-8)
		end
	end
end

function checkLogic()
	local sameSide = 0 -- 3 times on the same side breaks machine
	local lastSide = nil
	local diffSize = 0 -- 6 times on different sides gets coke

	for _, kick in ipairs(kicks) do
		if not lastSide or kick == lastSide then
			sameSide += 1
			diffSize = 1
		else
			sameSide = 1
			diffSize += 1
		end
		lastSide = kick
		if sameSide == 3 then
			state = kStateKick
			alert = "*You broke the machine!*"
			alertContinue = kAlertContinueTryAgain
			alertClearCallback = 
				function()
					kicks = {}
				end
			return
		elseif diffSize == 6 then
			state = kStatePull
			alert = "*Almost There!\nJust pull it out!*"
			alertContinue = kAlertContinueContinue
			alertClearCallback =
				function()
					print("pull")
					kicks = {}
					crankNeededDegrees = 360*3 -- 3 full circles
					crankCompleteCallback = 
						function()
							alert = "*FREE COKE!*"
							alertContinue = kAlertContinueNext
						end
					playdate.ui.crankIndicator:start()
					crankIndicatorShowing = true
				end 
		end
	end
end

gameSetup()

function cranked_level1(change, acceleratedChange)
	if not state == kStatePull then 
		return
	end
	
	crankIndicatorShowing = false
	
	if not crankCompleteCallback then
		return
	end

	crankNeededDegrees -= math.abs(change)
	if crankNeededDegrees <= 0 then
		crankCompleteCallback()
		crankCompleteCallback = nil
	end
end

function update_level1()
	if playdate.buttonJustPressed( playdate.kButtonA ) then
		if alert then
			alert = nil
			alertClearCallback()
			alertClearCallback = nil
		end
	end
	
	if state == kStateKick then
		if playdate.buttonJustPressed( playdate.kButtonRight ) then
			table.insert(kicks, kRight)
			kickSound:play()
			lockSprite:setRotation(-3)
			legRightSprite:add()
			playdate.timer.performAfterDelay(50, 
				function()
					lockSprite:setRotation(0)
					legRightSprite:remove()
				end
			)
			checkLogic()
		elseif playdate.buttonJustPressed( playdate.kButtonLeft ) then
			table.insert(kicks, kLeft)
			kickSound:play()
			lockSprite:setRotation(3)
			legLeftSprite:add()
			playdate.timer.performAfterDelay(50, 
				function()
					lockSprite:setRotation(0)
					legLeftSprite:remove()
				end
			)
			checkLogic()
		end
	end

	gfx.sprite.update()
	
	if crankIndicatorShowing then
		playdate.ui.crankIndicator:update()
	end
	
	-- shaker:update()
	
	drawLevelText()
	playdate.timer.updateTimers()
end