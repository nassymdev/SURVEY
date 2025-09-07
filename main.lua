

local BOARD = { x = 0, y = 0, w = 220, h = 220 }
local BOARD_ORIGINAL = { w = 220, h = 220 }
local BOARD_TARGET = { w = 220, h = 220 }
local boxAnimTime = 0
local boxAnimDuration = 0
local isBoxAnimating = false

local PLAYER = { x = 0, y = 0, w = 16, h = 16, speed = 200, hp = 500, hpMax = 500, iFrames = 0, iDur = 0.8 }
local soulImg, attacksImg, attackQuads = nil, nil, {}
local gasterBlasterImg, gasterBlasterQuads = nil, {}
local attacks = {}
local afterimages = {}
local time, spawnTimer, spawnInterval = 0, 0, 1.2
local gameOver, paused, transitionActive = false, false, true
local fontSmall, fontLarge, fontBold
local isFullscreen = false

local cam = { x = 0, y = 0, scale = 1, targetScale = 1, timer = 0 }
local shake = { t = 0, dur = 0, mag = 0 }

local ATT_SPR_W, ATT_SPR_H = 48, 48
local ATT_FRAMES = 10
local HITBOX_SIZE = 12

local GASTER_SPR_W, GASTER_SPR_H = 46, 57
local GASTER_FRAMES = 6

local transition = { 
  t = 0, 
  dur = 1.2,
  done = false, 
  afterimages = {},
  maxAfterimages = 8,
  spawnRate = 0.05
}


local soulAfterimages = {}
local soulAfterimageTimer = 0
local soulAfterimageInterval = 0.05

local attackPatterns = {
  "bones_horizontal",
  "bones_vertical", 
  "stars",
  "gaster_blasters",
  "spiral",
  "cross",
  "diamonds",
  "wave",
  "homing_stars",
  "laser_grid",
  "squeeze_horizontal",
  "squeeze_vertical",
  "shrink_expand",
  "gaster_circle",
  "bone_wall",
  "bone_rain",       
  "star_ring",       
  "blaster_sweep"    
}
local currentPattern = 1
local patternTimer = 0
local patternCooldown = 0


local sounds = {
    gaster_charge = nil,
    hit = nil,
    music = nil
}
local musicVolume = 0.7
local sfxVolume = 0.8


local introActive = true
local introVideo = nil
local introBox = { x = 0, y = 0, w = 400, h = 200, border = 4 }
local introText = {
    "Welcome to the battle arena,",
    "Where your skills will be tested...",
    "Prepare yourself for what's to come!",
    "The battle begins now!",
    "oh by the way",
    "thunderedge",
    "i will not hold back",
    
}
local currentTextLine = 1
local textDisplayTimer = 0
local textDisplayInterval = 3.0 
local videoScale = 1.0
local videoAlpha = 1.0

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end

local function easeInOutQuad(t)
  if t < 0.5 then
    return 2 * t * t
  else
    return 1 - 2 * (1 - t) * (1 - t)
  end
end

local function updateBoardPosition()
  BOARD.x = love.graphics.getWidth()/2 - BOARD.w/2
  BOARD.y = love.graphics.getHeight()/2 - BOARD.h/2
end

local function animateBoxTo(targetW, targetH, duration)
  BOARD_TARGET.w = targetW
  BOARD_TARGET.h = targetH
  boxAnimTime = 0
  boxAnimDuration = duration or 1.0
  isBoxAnimating = true
end

local function resetBoxSize()
  animateBoxTo(BOARD_ORIGINAL.w, BOARD_ORIGINAL.h, 0.8)
end

local function loadIntroVideo()
    pcall(function()
        if love.filesystem.getInfo('furina.ogv') then
            introVideo = love.graphics.newVideo('furina.ogv')
            introVideo:play()
            introVideo:setLooping(true)
        else
            print("Video file not found. Looking for: furina.ogv")
        end
    end)
end

local function resetGame()
  attacks = {}
  afterimages = {}
  time, spawnTimer, spawnInterval = 0, 0, 1.2
  gameOver, paused = false, false
  transitionActive = true  
  PLAYER.hp = PLAYER.hpMax
  PLAYER.iFrames = 0
  patternCooldown = 0
  
  BOARD.w = BOARD_ORIGINAL.w
  BOARD.h = BOARD_ORIGINAL.h
  BOARD_TARGET.w = BOARD_ORIGINAL.w
  BOARD_TARGET.h = BOARD_ORIGINAL.h
  isBoxAnimating = false
  boxAnimTime = 0
  
  updateBoardPosition()
  PLAYER.x = BOARD.x + BOARD.w/2 - PLAYER.w/2
  PLAYER.y = BOARD.y + BOARD.h/2 - PLAYER.h/2
  cam.scale = 1; cam.targetScale = 1; cam.timer = 0
  transition.t = 0; transition.done = false; transition.afterimages = {}
  currentPattern = 1
  patternTimer = 0
  
  
  introActive = true
  currentTextLine = 1
  textDisplayTimer = 0
  videoAlpha = 1.0
  
  
  if introVideo then
      introVideo:rewind()
      introVideo:play()
  end
  
  
  if sounds.music then
      sounds.music:stop()
  end
end

local function loadAssets()
  if love.filesystem.getInfo('assets/blaster.png') then
    attacksImg = love.graphics.newImage('assets/blaster.png')
    attacksImg:setFilter('nearest','nearest')
    attackQuads = {}
    for i=0,ATT_FRAMES-1 do
      attackQuads[i+1] = love.graphics.newQuad(i*ATT_SPR_W,0,ATT_SPR_W,ATT_SPR_H,attacksImg:getDimensions())
    end
  end
  
  if love.filesystem.getInfo('assets/blaster.png') then
    gasterBlasterImg = love.graphics.newImage('assets/blaster.png')
    gasterBlasterImg:setFilter('nearest','nearest')
    gasterBlasterQuads = {}
    for i=0, GASTER_FRAMES-1 do
      gasterBlasterQuads[i+1] = love.graphics.newQuad(i*GASTER_SPR_W, 0, GASTER_SPR_W, GASTER_SPR_H, gasterBlasterImg:getDimensions())
    end
  end
  
  if love.filesystem.getInfo('assets/soul.png') then
    soulImg = love.graphics.newImage('assets/soul.png')
    soulImg:setFilter('nearest','nearest')
  end
end

local function loadAudio()
    
    pcall(function()
        if love.filesystem.getInfo('sounds/gaster.mp3') then
            sounds.gaster_charge = love.audio.newSource('sounds/gaster.mp3', 'static')
            sounds.gaster_charge:setVolume(sfxVolume)
        end
    end)
    
    pcall(function()
        if love.filesystem.getInfo('sounds/damage.mp3') then
            sounds.hit = love.audio.newSource('sounds/damage.mp3', 'static')
            sounds.hit:setVolume(sfxVolume)
        end
    end)
    
    
    pcall(function()
        if love.filesystem.getInfo('sounds/MEGALOVANIA.mp3') then
            sounds.music = love.audio.newSource('sounds/MEGALOVANIA.mp3', 'stream')
            sounds.music:setLooping(true)
            sounds.music:setVolume(musicVolume)
        end
    end)
    
    print("Audio loaded:")
    print("Music: " .. (sounds.music and "OK" or "MISSING"))
    print("Gaster sound: " .. (sounds.gaster_charge and "OK" or "MISSING"))
    print("Hit sound: " .. (sounds.hit and "OK" or "MISSING"))
end

local function dist(x1,y1,x2,y2) return math.sqrt((x2-x1)^2 + (y2-y1)^2) end

local function checkCollision(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

local function damagePlayer(amount)
  if PLAYER.iFrames <= 0 then
    PLAYER.hp = math.max(0, PLAYER.hp - amount)
    PLAYER.iFrames = PLAYER.iDur
    shake.t = 0.5; shake.dur = 0.5; shake.mag = 20
    
    
    if sounds.hit then
        sounds.hit:stop()
        sounds.hit:play()
    end
    
    if PLAYER.hp <= 0 then 
        gameOver = true 
        if sounds.music then
            sounds.music:stop()
        end
    end
  end
end

local function createBoneHorizontal(targetY, speed, fromLeft)
  local x = fromLeft and (BOARD.x - 100) or (BOARD.x + BOARD.w + 100)
  return {
    type = "bone",
    x = x, y = targetY - 4, w = 60, h = 8,
    vx = 0, vy = 0,
    originalVx = fromLeft and speed * 6.0 or -speed * 6.0,
    life = 8,
    targetY = targetY,
    warningTime = 0.5,
    currentTime = 0,
    charging = false
  }
end

local function createBoneVertical(targetX, speed, fromTop)
  local y = fromTop and (BOARD.y - 100) or (BOARD.y + BOARD.h + 100)
  return {
    type = "bone",
    x = targetX - 4, y = y, w = 8, h = 60,
    vx = 0, vy = 0,
    originalVy = fromTop and speed * 6.0 or -speed * 6.0,
    life = 8,
    targetX = targetX,
    warningTime = 0.5,
    currentTime = 0,
    charging = false
  }
end

local function createGasterBlaster(x, y, targetX, targetY, chargeTime, beamDuration)
  local angle = math.atan2(targetY - y, targetX - x)
  return {
    type = "gaster_blaster",
    x = x, y = y,
    w = 60, h = 75, 
    targetX = targetX, targetY = targetY,
    angle = angle,
    life = chargeTime + beamDuration + 0.5,
    chargeTime = chargeTime or 0.8,
    beamDuration = beamDuration or 1.5,
    currentTime = 0,
    phase = "appearing",
    scale = 0.1,
    animFrame = 1,
    animTimer = 0,
    animSpeed = 0.15,
    beam = {
      x = x, y = y,
      w = 0, h = 25, 
      active = false,
      length = 0,
      maxLength = 600
    }
  }
end

local function createStar(x, y, radius, speed)
  return {
    type = "star",
    x = x, y = y, w = radius*2, h = radius*2,
    vx = (math.random()-0.5)*speed*2.5,
    vy = (math.random()-0.5)*speed*2.5,
    radius = radius,
    life = 12,
    bounce = true,
    rotation = 0,
    rotSpeed = math.random(4, 10) * (math.random() > 0.5 and 1 or -1)
  }
end

local function createDiamond(x, y, speed)
  local angle = math.random() * math.pi * 2
  return {
    type = "diamond",
    x = x, y = y, w = 16, h = 16,
    vx = math.cos(angle) * speed * 1.5,
    vy = math.sin(angle) * speed * 1.5,
    life = 10,
    rotation = 0,
    rotSpeed = math.random(4, 8)
  }
end

local function createHomingStar(x, y, speed)
  return {
    type = "homing_star",
    x = x, y = y, w = 20, h = 20,
    vx = 0, vy = 0,
    speed = speed * 1.4,
    life = 15,
    radius = 10,
    rotation = 0,
    rotSpeed = 6,
    homingStrength = 1.2
  }
end

local function createLaser(x, y, w, h, direction, speed)
  return {
    type = "laser",
    x = x, y = y, w = w, h = h,
    vx = direction == "horizontal" and speed * 1.5 or 0,
    vy = direction == "vertical" and speed * 1.5 or 0,
    direction = direction,
    life = 8,
    warningTime = 0.4,
    currentTime = 0,
    active = false
  }
end

local function createWaveAttack(x, y, waveSpeed, amplitude)
  return {
    type = "wave",
    x = x, y = y, w = 14, h = 14,
    vx = waveSpeed * 1.3,
    vy = 0,
    baseY = y,
    amplitude = amplitude,
    frequency = 3,
    waveTime = 0,
    life = 12
  }
end

local function spawnBonesHorizontal()
  local count = math.random(2, 4)
  for i = 1, count do
    local targetY = BOARD.y + (i * BOARD.h / (count + 1))
    local fromLeft = math.random() > 0.5
    table.insert(attacks, createBoneHorizontal(targetY, 150 + math.random(100), fromLeft))
  end
end

local function spawnBonesVertical()
  local count = math.random(2, 4)
  for i = 1, count do
    local targetX = BOARD.x + (i * BOARD.w / (count + 1))
    local fromTop = math.random() > 0.5
    table.insert(attacks, createBoneVertical(targetX, 150 + math.random(100), fromTop))
  end
end

local function spawnStars()
  for i = 1, math.random(3, 6) do
    local x = BOARD.x + math.random(30, BOARD.w - 30)
    local y = BOARD.y + math.random(30, BOARD.h - 30)
    table.insert(attacks, createStar(x, y, 6 + math.random(4), 100 + math.random(50)))
  end
end

local function spawnGasterBlasters()
  local playerCenterX = PLAYER.x + PLAYER.w/2
  local playerCenterY = PLAYER.y + PLAYER.h/2
  
  for i = 1, 2 do
    local side = math.random(4)
    local blasterX, blasterY
    
    if side == 1 then 
      blasterX, blasterY = BOARD.x - 80, BOARD.y + math.random(BOARD.h)
    elseif side == 2 then 
      blasterX, blasterY = BOARD.x + BOARD.w + 80, BOARD.y + math.random(BOARD.h)
    elseif side == 3 then 
      blasterX, blasterY = BOARD.x + math.random(BOARD.w), BOARD.y - 80
    else 
      blasterX, blasterY = BOARD.x + math.random(BOARD.w), BOARD.y + BOARD.h + 80
    end
    
    table.insert(attacks, createGasterBlaster(blasterX, blasterY, playerCenterX, playerCenterY, 0.8, 1.8))
  end
end

local function spawnGasterCircle()
  local centerX, centerY = BOARD.x + BOARD.w/2, BOARD.y + BOARD.h/2
  local playerCenterX = PLAYER.x + PLAYER.w/2
  local playerCenterY = PLAYER.y + PLAYER.h/2
  
  for i = 0, 5 do
    local angle = i * math.pi/3
    local distance = 200
    local blasterX = centerX + math.cos(angle) * distance
    local blasterY = centerY + math.sin(angle) * distance
    
    table.insert(attacks, createGasterBlaster(blasterX, blasterY, playerCenterX, playerCenterY, 1.2, 2.0))
  end
end

local function spawnBoneWall()
  local gapPosition = math.random(2, 5)
  local fromLeft = math.random() > 0.5
  
  for i = 1, 6 do
    if i ~= gapPosition then
      local targetY = BOARD.y + (i-1) * (BOARD.h / 5)
      table.insert(attacks, createBoneHorizontal(targetY, 180, fromLeft))
    end
  end
end

local function spawnSpiral()
  local centerX, centerY = BOARD.x + BOARD.w/2, BOARD.y + BOARD.h/2
  for i = 0, 6 do
    local angle = time * 2.5 + i * math.pi/3.5
    table.insert(attacks, {
      type = "spiral",
      x = centerX + math.cos(angle) * 50,
      y = centerY + math.sin(angle) * 50,
      w = 12, h = 12,
      vx = math.cos(angle + math.pi/2) * 90,
      vy = math.sin(angle + math.pi/2) * 90,
      angle = angle,
      life = 10
    })
  end
end

local function spawnCross()
  local targetY = PLAYER.y + PLAYER.h/2
  local targetX = PLAYER.x + PLAYER.w/2
  
  for offset = -20, 20, 20 do
    table.insert(attacks, createBoneHorizontal(targetY + offset, 200, true))
    table.insert(attacks, createBoneHorizontal(targetY + offset, 200, false))
    table.insert(attacks, createBoneVertical(targetX + offset, 200, true))
    table.insert(attacks, createBoneVertical(targetX + offset, 200, false))
  end
end

local function spawnDiamonds()
  for i = 1, math.random(4, 8) do
    local x = BOARD.x + math.random(BOARD.w)
    local y = BOARD.y + math.random(BOARD.h)
    table.insert(attacks, createDiamond(x, y, 90 + math.random(40)))
  end
end

local function spawnWave()
  local startY = BOARD.y + math.random(60, BOARD.h - 60)
  for i = 0, 2 do
    table.insert(attacks, createWaveAttack(BOARD.x - 20, startY + i * 40, 120, 30 + i * 10))
  end
end

local function spawnHomingStars()
  for i = 1, math.random(2, 4) do
    local side = math.random(4)
    local x, y
    if side == 1 then x, y = BOARD.x - 50, BOARD.y + math.random(BOARD.h)
    elseif side == 2 then x, y = BOARD.x + BOARD.w + 50, BOARD.y + math.random(BOARD.h)
    elseif side == 3 then x, y = BOARD.x + math.random(BOARD.w), BOARD.y - 50
    else x, y = BOARD.x + math.random(BOARD.w), BOARD.y + BOARD.h + 50
    end
    table.insert(attacks, createHomingStar(x, y, 80 + math.random(30)))
  end
end

local function spawnLaserGrid()
  for i = 0, 2 do
    local x = BOARD.x + (i + 1) * BOARD.w / 4
    table.insert(attacks, createLaser(x - 4, BOARD.y - 20, 8, BOARD.h + 40, "vertical", 120))
  end
  
  for i = 0, 1 do
    local y = BOARD.y + (i + 1) * BOARD.h / 3
    table.insert(attacks, createLaser(BOARD.x - 20, y - 4, BOARD.w + 40, 8, "horizontal", 120))
  end
end

local function spawnSqueezeHorizontal()
  animateBoxTo(100, BOARD.h, 1.0)
  patternCooldown = 1.5
end

local function spawnSqueezeVertical()
  animateBoxTo(BOARD.w, 100, 1.0)
  patternCooldown = 1.5
end

local function spawnShrinkExpand()
  animateBoxTo(80, 80, 0.8)
  patternCooldown = 2.0
end


local function spawnBoneRain()
  for i = 1, 8 do
    local x = BOARD.x + math.random(BOARD.w)
    table.insert(attacks, {
      type = "bone",
      x = x, y = BOARD.y - 40,
      w = 8, h = 40,
      vx = 0, vy = 250,
      life = 6, charging = true
    })
  end
end

local function spawnStarRing()
  local centerX, centerY = BOARD.x + BOARD.w/2, BOARD.y + BOARD.h/2
  for i = 0, 11 do
    local angle = i * math.pi/6
    local speed = 120
    table.insert(attacks, {
      type = "star",
      x = centerX, y = centerY,
      w = 16, h = 16,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      radius = 8, life = 10, rotation = 0,
      rotSpeed = 5
    })
  end
end

local function spawnBlasterSweep()
  local playerCenterX, playerCenterY = PLAYER.x + PLAYER.w/2, PLAYER.y + PLAYER.h/2
  for i = -2, 2 do
    local bx = BOARD.x - 120
    local by = BOARD.y + BOARD.h/2 + i * 60
    table.insert(attacks, createGasterBlaster(bx, by, playerCenterX, playerCenterY, 0.8 + i*0.2, 1.5))
  end
end

function love.load()
  love.window.setFullscreen(true)
  love.window.setTitle('Aggressive Deltarune Combat with Animated Gaster Blasters')
  love.graphics.setDefaultFilter('nearest','nearest')
  fontSmall = love.graphics.newFont(12)
  fontLarge = love.graphics.newFont(22)
  fontBold = love.graphics.newFont(18) 
  
  loadAssets()
  loadAudio()
  
  
  loadIntroVideo()
  
  resetGame()
  
  
  introActive = true
end

function love.keypressed(key)
  if introActive then
    if key == 'space' then
        
        currentTextLine = currentTextLine + 1
        
        
        if currentTextLine > #introText then
            introActive = false
            transitionActive = true
            if sounds.music then
                sounds.music:play()
            end
        end
        return
    elseif key == 'return' then
        
        introActive = false
        transitionActive = true
        if sounds.music then
            sounds.music:play()
        end
        return
    end
  end

  if key == 'escape' then love.event.quit() end
  if key == 'p' then 
    paused = not paused 
    if sounds.music then
        if paused then
            sounds.music:pause()
        else
            sounds.music:play()
        end
    end
  end
  if key == 'r' then resetGame() end
  if key == "f11" then
    isFullscreen = not isFullscreen
    love.window.setFullscreen(isFullscreen)
    updateBoardPosition()
    if not transitionActive then
      PLAYER.x = BOARD.x + BOARD.w/2 - PLAYER.w/2
      PLAYER.y = BOARD.y + BOARD.h/2 - PLAYER.h/2
    end
  end
  
  
  if key == '[' then
      musicVolume = math.max(0, musicVolume - 0.1)
      if sounds.music then sounds.music:setVolume(musicVolume) end
  end
  if key == ']' then
      musicVolume = math.min(1, musicVolume + 0.1)
      if sounds.music then sounds.music:setVolume(musicVolume) end
  end
  
  
  if key == '1' and sounds.gaster_charge then
      sounds.gaster_charge:stop()
      sounds.gaster_charge:setPitch(1.0)
      sounds.gaster_charge:play()
  end
  if key == '2' and sounds.gaster_charge then
      sounds.gaster_charge:stop()
      sounds.gaster_charge:setPitch(1.5)
      sounds.gaster_charge:play()
  end
  if key == '3' and sounds.hit then
      sounds.hit:stop()
      sounds.hit:play()
  end
end

function love.update(dt)
  if introActive then
    
    if introVideo then
        videoAlpha = math.min(1.0, videoAlpha + dt * 2)
    end
    
    return 
  end

  if paused or gameOver then return end

  if transitionActive then
    transition.t = transition.t + dt
    
    if transition.t > 0.2 then
      if math.random() < transition.spawnRate / dt then
        if #transition.afterimages < transition.maxAfterimages then
          table.insert(transition.afterimages, { 
            t = transition.t,
            scale = 0.7 + math.random() * 0.6,
            rotation = math.random() * math.pi * 2,
            opacity = 0.8 + math.random() * 0.2
          })
        end
      end
    end
    
    for i = #transition.afterimages, 1, -1 do
      local ai = transition.afterimages[i]
      local age = transition.t - ai.t
      ai.opacity = math.max(0, ai.opacity - age * 2.0)
      if ai.opacity <= 0 then
        table.remove(transition.afterimages, i)
      end
    end
    
    if transition.t >= transition.dur and not transition.done then
      transition.done = true
      transitionActive = false
    end
    return
  end

  time = time + dt
  patternTimer = patternTimer + dt
  if patternCooldown > 0 then
    patternCooldown = patternCooldown - dt
  end
  
  if isBoxAnimating then
    boxAnimTime = boxAnimTime + dt
    local t = math.min(boxAnimTime / boxAnimDuration, 1.0)
    local easedT = easeInOutQuad(t)
    
    BOARD.w = lerp(BOARD.w, BOARD_TARGET.w, easedT * 0.15)
    BOARD.h = lerp(BOARD.h, BOARD_TARGET.h, easedT * 0.15)
    
    updateBoardPosition()
    PLAYER.x = clamp(PLAYER.x, BOARD.x, BOARD.x + BOARD.w - PLAYER.w)
    PLAYER.y = clamp(PLAYER.y, BOARD.y, BOARD.y + BOARD.h - PLAYER.h)
    
    if t >= 1.0 then
      isBoxAnimating = false
      boxAnimTime = 0
    end
  end
  
  if shake.t > 0 then
    shake.t = shake.t - dt
    if shake.t <= 0 then shake.mag = 0 end
  end

  if PLAYER.iFrames > 0 then PLAYER.iFrames = math.max(0, PLAYER.iFrames - dt) end

  local dx, dy = 0,0
  if love.keyboard.isDown('left','a') then dx = dx - 1 end
  if love.keyboard.isDown('right','d') then dx = dx + 1 end
  if love.keyboard.isDown('up','w') then dy = dy - 1 end
  if love.keyboard.isDown('down','s') then dy = dy + 1 end
  if dx ~= 0 and dy ~= 0 then local inv = 1/math.sqrt(2); dx,dy = dx*inv, dy*inv end
  PLAYER.x = clamp(PLAYER.x + dx * PLAYER.speed * dt, BOARD.x, BOARD.x + BOARD.w - PLAYER.w)
  PLAYER.y = clamp(PLAYER.y + dy * PLAYER.speed * dt, BOARD.y, BOARD.y + BOARD.h - PLAYER.h)

  
  soulAfterimageTimer = soulAfterimageTimer + dt
  if soulAfterimageTimer >= soulAfterimageInterval then
    soulAfterimageTimer = 0
    table.insert(soulAfterimages, {
      x = PLAYER.x,
      y = PLAYER.y,
      alpha = 0.7,
      life = 0.3
    })
  end

  
  for i = #soulAfterimages, 1, -1 do
    soulAfterimages[i].life = soulAfterimages[i].life - dt
    soulAfterimages[i].alpha = soulAfterimages[i].alpha - dt * 2.5
    if soulAfterimages[i].life <= 0 then
      table.remove(soulAfterimages, i)
    end
  end

  spawnTimer = spawnTimer + dt
  if spawnTimer >= spawnInterval and patternCooldown <= 0 then
    spawnTimer = 0
    
    local pattern = attackPatterns[currentPattern]
    if pattern == "bones_horizontal" then
      spawnBonesHorizontal()
    elseif pattern == "bones_vertical" then
      spawnBonesVertical()
    elseif pattern == "stars" then
      spawnStars()
    elseif pattern == "gaster_blasters" then
      spawnGasterBlasters()
    elseif pattern == "gaster_circle" then
      spawnGasterCircle()
    elseif pattern == "bone_wall" then
      spawnBoneWall()
    elseif pattern == "spiral" then
      spawnSpiral()
    elseif pattern == "cross" then
      spawnCross()
    elseif pattern == "diamonds" then
      spawnDiamonds()
    elseif pattern == "wave" then
      spawnWave()
    elseif pattern == "homing_stars" then
      spawnHomingStars()
    elseif pattern == "laser_grid" then
      spawnLaserGrid()
    elseif pattern == "squeeze_horizontal" then
      spawnSqueezeHorizontal()
    elseif pattern == "squeeze_vertical" then
      spawnSqueezeVertical()
    elseif pattern == "shrink_expand" then
      spawnShrinkExpand()
    elseif pattern == "bone_rain" then
      spawnBoneRain()
    elseif pattern == "star_ring" then
      spawnStarRing()
    elseif pattern == "blaster_sweep" then
      spawnBlasterSweep()
    end
    
    if patternTimer >= 5 then
      patternTimer = 0
      currentPattern = (currentPattern % #attackPatterns) + 1
      if not isBoxAnimating and (BOARD.w ~= BOARD_ORIGINAL.w or BOARD.h ~= BOARD_ORIGINAL.h) then
        resetBoxSize()
      end
    end
  end

  for i = #attacks, 1, -1 do
    local att = attacks[i]
    att.currentTime = (att.currentTime or 0) + dt
    
    if att.type == "gaster_blaster" then
      
      att.animTimer = att.animTimer + dt
      if att.animTimer >= att.animSpeed then
        att.animTimer = 0
        if att.phase == "charging" or att.phase == "firing" then
          att.animFrame = (att.animFrame % GASTER_FRAMES) + 1
          
          
          if att.phase == "charging" and att.animFrame == 3 then
            att.phase = "firing"
            att.beam.active = true
            shake.t = 1.0; shake.dur = 1.0; shake.mag = 15
            
            
            if sounds.gaster_charge then
                sounds.gaster_charge:stop()
                sounds.gaster_charge:setPitch(1.5) 
                sounds.gaster_charge:play()
            end
          end
        end
      end
      
      if att.phase == "appearing" then
        att.scale = math.min(1.0, att.scale + dt * 4)
        if att.scale >= 1.0 then
          att.phase = "charging"
          
          
          if sounds.gaster_charge then
              sounds.gaster_charge:stop()
              sounds.gaster_charge:setPitch(1.0) 
              sounds.gaster_charge:play()
          end
        end
      elseif att.phase == "charging" then
        
        local playerCenterX = PLAYER.x + PLAYER.w/2
        local playerCenterY = PLAYER.y + PLAYER.h/2
        att.angle = math.atan2(playerCenterY - att.y, playerCenterX - att.x)
        
        
        if att.currentTime >= att.chargeTime then
          att.phase = "firing"
          att.beam.active = true
          shake.t = 1.0; shake.dur = 1.0; shake.mag = 15
          
          
          if sounds.gaster_charge then
              sounds.gaster_charge:stop()
              sounds.gaster_charge:setPitch(1.5)
              sounds.gaster_charge:play()
          end
        end
      elseif att.phase == "firing" then
        att.beam.length = math.min(att.beam.maxLength, att.beam.length + dt * 1200)
        if att.currentTime >= att.chargeTime + att.beamDuration then
          att.phase = "disappearing"
          att.beam.active = false
        end
      elseif att.phase == "disappearing" then
        att.scale = math.max(0, att.scale - dt * 6)
      end
    end
    
    if att.type == "bone" and not att.charging then
      if att.currentTime >= att.warningTime then
        att.charging = true
        att.vx = att.originalVx or att.vx
        att.vy = att.originalVy or att.vy
        shake.t = 0.4; shake.dur = 0.4; shake.mag = 12
      end
    end
    
    if att.type == "laser" and not att.active then
      if att.currentTime >= att.warningTime then
        att.active = true
      end
    end
    
    if att.type == "homing_star" then
      local dx = (PLAYER.x + PLAYER.w/2) - (att.x + att.w/2)
      local dy = (PLAYER.y + PLAYER.h/2) - (att.y + att.h/2)
      local distance = math.sqrt(dx*dx + dy*dy)
      if distance > 0 then
        att.vx = att.vx + (dx/distance) * att.homingStrength * att.speed * dt
        att.vy = att.vy + (dy/distance) * att.homingStrength * att.speed * dt
        
        local currentSpeed = math.sqrt(att.vx*att.vx + att.vy*att.vy)
        if currentSpeed > att.speed then
          att.vx = att.vx / currentSpeed * att.speed
          att.vy = att.vy / currentSpeed * att.speed
        end
      end
      att.rotation = att.rotation + att.rotSpeed * dt
    end
    
    if att.type == "wave" then
      att.waveTime = att.waveTime + dt
      att.y = att.baseY + math.sin(att.waveTime * att.frequency) * att.amplitude
    end
    
    if att.rotSpeed then
      att.rotation = (att.rotation or 0) + att.rotSpeed * dt
    end
    
    if att.type ~= "gaster_blaster" then
      att.x = att.x + att.vx * dt
      att.y = att.y + att.vy * dt
    end
    att.life = att.life - dt
    
    if att.type == "star" and att.bounce then
      if att.x <= BOARD.x or att.x + att.w >= BOARD.x + BOARD.w then
        att.vx = -att.vx
        att.x = clamp(att.x, BOARD.x, BOARD.x + BOARD.w - att.w)
      end
      if att.y <= BOARD.y or att.y + att.h >= BOARD.y + BOARD.h then
        att.vy = -att.vy  
        att.y = clamp(att.y, BOARD.y, BOARD.y + BOARD.h - att.h)
      end
    end
    
    local canHit = true
    if att.type == "bone" and not att.charging then canHit = false end
    if att.type == "laser" and not att.active then canHit = false end
    
    
    if att.type == "gaster_blaster" and att.beam.active then
      
      local beamWorldX = att.x + math.cos(att.angle - math.pi/2) * (att.h/2 - 5)
      local beamWorldY = att.y + math.sin(att.angle - math.pi/2) * (att.h/2 - 5)
      
      
      local beamCos = math.cos(att.angle - math.pi/2)
      local beamSin = math.sin(att.angle - math.pi/2)
      
      
      local beamEndX = beamWorldX + beamCos * att.beam.length
      local beamEndY = beamWorldY + beamSin * att.beam.length
      
      
      local playerCenterX = PLAYER.x + PLAYER.w/2
      local playerCenterY = PLAYER.y + PLAYER.h/2
      
      
      local toPlayerX = playerCenterX - beamWorldX
      local toPlayerY = playerCenterY - beamWorldY
      
      
      local projection = toPlayerX * beamCos + toPlayerY * beamSin
      
      
      if projection >= 0 and projection <= att.beam.length then
        
        local perpDistance = math.abs(toPlayerX * (-beamSin) + toPlayerY * beamCos)
        
        
        if perpDistance <= att.beam.h/2 then
          canHit = true
        else
          canHit = false
        end
      else
        canHit = false
      end
    elseif att.type == "gaster_blaster" then
      canHit = false
    end
    
    if canHit and checkCollision(att.x, att.y, att.w, att.h, PLAYER.x, PLAYER.y, PLAYER.w, PLAYER.h) then
      damagePlayer(15)
    end
    
    if att.life <= 0 then
      table.remove(attacks, i)
    end
  end
end

function love.draw()
  if introActive then
    love.graphics.clear(0, 0, 0)
    
    
    if introVideo then
        local vidWidth, vidHeight = introVideo:getDimensions()
        
        local fixedScale = 0.7
        local drawWidth = vidWidth * fixedScale
        local drawHeight = vidHeight * fixedScale
        
        love.graphics.setColor(1, 1, 1, videoAlpha)
        love.graphics.draw(introVideo, 
                          love.graphics.getWidth()/2 - drawWidth/2,
                          love.graphics.getHeight()/2 - drawHeight/2 - 50, 
                          0, fixedScale, fixedScale)
    else
        
        love.graphics.setColor(0.2, 0.2, 0.8, 0.7)
        love.graphics.rectangle('fill', love.graphics.getWidth()/2 - 200, love.graphics.getHeight()/2 - 150, 400, 300)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fontLarge)
        love.graphics.printf("INTRO VIDEO", love.graphics.getWidth()/2 - 200, love.graphics.getHeight()/2 - 20, 400, 'center')
    end
    
    
    introBox.x = love.graphics.getWidth()/2 - introBox.w/2
    introBox.y = love.graphics.getHeight() - introBox.h - 20  
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', introBox.x, introBox.y, introBox.w, introBox.h)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(introBox.border)
    love.graphics.rectangle('line', introBox.x, introBox.y, introBox.w, introBox.h)
    
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fontBold)
    love.graphics.printf(introText[currentTextLine], 
                        introBox.x + 20, 
                        introBox.y + introBox.h/2 - 15, 
                        introBox.w - 40, 'center')
    
    
    love.graphics.setFont(fontSmall)
    love.graphics.printf("(" .. currentTextLine .. "/" .. #introText .. ")", 
                        introBox.x, 
                        introBox.y + introBox.h - 25, 
                        introBox.w, 'center')
    
    
    love.graphics.printf("Press SPACE to continue, ENTER to skip", 
                        0, 
                        love.graphics.getHeight() - 20, 
                        love.graphics.getWidth(), 'center')
    
    return 
  end

  love.graphics.clear(0,0,0)
  
  local shakeX, shakeY = 0, 0
  if shake.t > 0 then
    shakeX = (math.random() - 0.5) * shake.mag
    shakeY = (math.random() - 0.5) * shake.mag
  end
  love.graphics.push()
  love.graphics.translate(shakeX, shakeY)

  if transitionActive then
    local t = clamp(transition.t/transition.dur, 0,1)
    local scale = 0.05 + t * (1 - 0.05)
    local rotation = t * 4*math.pi
    local cx, cy = BOARD.x + BOARD.w/2, BOARD.y + BOARD.h/2

    for _, ai in ipairs(transition.afterimages) do
      local age = transition.t - ai.t
      local fadeOpacity = clamp(ai.opacity * (1 - age/1.5), 0, 1)
      
      love.graphics.setColor(0, 1, 0, fadeOpacity * 0.6)
      love.graphics.push()
      love.graphics.translate(cx, cy)
      love.graphics.rotate(ai.rotation + rotation * 0.8)
      love.graphics.scale(ai.scale * scale, ai.scale * scale)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle('line', -BOARD.w/2, -BOARD.h/2, BOARD.w, BOARD.h)
      love.graphics.pop()
    end

    love.graphics.setColor(0, 1, 0, 0.9)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(rotation)
    love.graphics.scale(scale, scale)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', -BOARD.w/2, -BOARD.h/2, BOARD.w, BOARD.h)
    love.graphics.pop()
    
    love.graphics.pop()
    return
  end

  love.graphics.setColor(0.06, 0.06, 0.06)
  love.graphics.rectangle('fill', BOARD.x, BOARD.y, BOARD.w, BOARD.h)
  
  local borderIntensity = 1.0
  if isBoxAnimating then
    borderIntensity = 0.5 + 0.5 * math.sin(time * 12)
  end
  love.graphics.setLineWidth(4)
  love.graphics.setColor(0, borderIntensity, 0)
  love.graphics.rectangle('line', BOARD.x, BOARD.y, BOARD.w, BOARD.h)
  
  
  if introVideo then
      local vidWidth, vidHeight = introVideo:getDimensions()
      
      local fixedScale = 0.4
      local drawWidth = vidWidth * fixedScale
      local drawHeight = vidHeight * fixedScale
      
      love.graphics.setColor(1, 1, 1, 0.6) 
      love.graphics.draw(introVideo, 
                        love.graphics.getWidth()/2 - drawWidth/2,
                        BOARD.y - drawHeight - 20, 
                        0, fixedScale, fixedScale)
  end

  for _, att in ipairs(attacks) do
    local isWarning = (att.currentTime or 0) < (att.warningTime or 0)
    local alpha = 1.0
    
    if att.type == "gaster_blaster" then
      love.graphics.push()
      love.graphics.translate(att.x, att.y)
      love.graphics.rotate(att.angle - math.pi/2) 
      love.graphics.scale(att.scale, att.scale)
      
      if gasterBlasterImg and gasterBlasterQuads[att.animFrame] then
        if att.phase == "charging" then
          local intensity = 0.7 + 0.3 * math.sin(att.currentTime * 12)
          love.graphics.setColor(1, intensity, intensity, 0.95)
        elseif att.phase == "firing" then
          love.graphics.setColor(1, 0.9, 0.9, 1.0)
        else
          love.graphics.setColor(0.9, 0.9, 1, 0.9)
        end
        
        love.graphics.draw(gasterBlasterImg, gasterBlasterQuads[att.animFrame], 
                          -att.w/2, -att.h/2, 0, att.w/GASTER_SPR_W, att.h/GASTER_SPR_H)
      else
        if att.phase == "charging" then
          local intensity = 0.5 + 0.5 * math.sin(att.currentTime * 10)
          love.graphics.setColor(1, intensity, intensity, 0.9)
        else
          love.graphics.setColor(0.8, 0.8, 0.9, 0.9)
        end
        
        love.graphics.push()
        love.graphics.scale(1.5, 1)
        love.graphics.circle('fill', 0, 0, 25)
        love.graphics.pop()
        
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
        love.graphics.circle('fill', -12, -10, 6)
        love.graphics.circle('fill', 12, -10, 6)
        
        if att.phase == "charging" then
          local glowIntensity = 0.5 + 0.5 * math.sin(att.currentTime * 15)
          love.graphics.setColor(1, 0.3, 0.3, glowIntensity)
          love.graphics.circle('fill', -12, -10, 4)
          love.graphics.circle('fill', 12, -10, 4)
        end
      end
      
      
      if att.beam.active then
        local mouthY = att.h/2 - 5  

        
        love.graphics.setColor(1, 1, 1, 0.95)
        
        love.graphics.rectangle('fill', -att.beam.h/2, mouthY, att.beam.h, att.beam.length)

        
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle('fill', -att.beam.h/2 - 2, mouthY - 2, att.beam.h + 4, att.beam.length + 4)
      end

      love.graphics.pop()
      
    else
      if isWarning then
        alpha = 0.3 + 0.7 * math.sin((att.currentTime or 0) * 15)
        love.graphics.setColor(1, 0.8, 0, alpha)
      else
        love.graphics.setColor(1, 1, 1, alpha)
      end
      
      if att.type == "bone" then
        love.graphics.rectangle('fill', att.x, att.y, att.w, att.h)
        if not isWarning then
          love.graphics.setColor(0.8, 0.8, 0.8, alpha)
          love.graphics.setLineWidth(1)
          love.graphics.rectangle('line', att.x, att.y, att.w, att.h)
        end
      elseif att.type == "star" then
        love.graphics.push()
        love.graphics.translate(att.x + att.w/2, att.y + att.h/2)
        love.graphics.rotate(att.rotation or 0)
        local r = att.radius
        local points = {}
        for i = 0, 9 do
          local angle = i * math.pi / 5
          local radius = (i % 2 == 0) and r or r * 0.4
          table.insert(points, math.cos(angle) * radius)
          table.insert(points, math.sin(angle) * radius)
        end
        love.graphics.polygon('fill', points)
        love.graphics.pop()
      elseif att.type == "spiral" then
        love.graphics.push()
        love.graphics.translate(att.x + att.w/2, att.y + att.h/2)
        love.graphics.rotate(att.angle or 0)
        local size = att.w/2
        love.graphics.polygon('fill', 
          -size, -size*0.3, -size*0.3, -size,
          size*0.3, -size, size, -size*0.3,
          size, size*0.3, size*0.3, size,
          -size*0.3, size, -size, size*0.3
        )
        love.graphics.pop()
      elseif att.type == "diamond" then
        love.graphics.push()
        love.graphics.translate(att.x + att.w/2, att.y + att.h/2)
        love.graphics.rotate(att.rotation or 0)
        local size = att.w/2
        love.graphics.polygon('fill', 0, -size, size, 0, 0, size, -size, 0)
        love.graphics.pop()
      elseif att.type == "homing_star" then
        love.graphics.push()
        love.graphics.translate(att.x + att.w/2, att.y + att.h/2)
        love.graphics.rotate(att.rotation or 0)
        local r = att.radius
        local points = {}
        for i = 0, 11 do
          local angle = i * math.pi / 6
          local radius = (i % 2 == 0) and r or r * 0.5
          table.insert(points, math.cos(angle) * radius)
          table.insert(points, math.sin(angle) * radius)
        end
        love.graphics.polygon('fill', points)
        love.graphics.pop()
      elseif att.type == "wave" then
        love.graphics.circle('fill', att.x + att.w/2, att.y + att.h/2, att.w/2)
      elseif att.type == "laser" then
        if att.active then
          love.graphics.setColor(1, 0.2, 0.2, alpha)
        end
        love.graphics.rectangle('fill', att.x, att.y, att.w, att.h)
      end
    end
  end

  
  for _, ai in ipairs(soulAfterimages) do
    if soulImg then
      love.graphics.setColor(1, 1, 1, ai.alpha)
      love.graphics.draw(soulImg, ai.x, ai.y)
    else
      love.graphics.setColor(1, 0.25, 0.3, ai.alpha)
      love.graphics.rectangle('fill', ai.x, ai.y, PLAYER.w, PLAYER.h)
    end
  end

  local playerVisible = true
  if PLAYER.iFrames > 0 then
    playerVisible = math.floor(time * 15) % 2 == 0
  end
  
  if playerVisible then
    if soulImg then
      love.graphics.setColor(1,1,1)
      love.graphics.draw(soulImg, PLAYER.x, PLAYER.y)
    else
      love.graphics.setColor(1,0.25,0.3)
      love.graphics.rectangle('fill', PLAYER.x, PLAYER.y, PLAYER.w, PLAYER.h)
    end
  end

  
  local hpBarWidth = 200
  local hpBarHeight = 15
  local hpBarX = BOARD.x + BOARD.w/2 - hpBarWidth/2
  local hpBarY = BOARD.y + BOARD.h + 20
  
  
  love.graphics.setColor(0.2, 0.2, 0.2)
  love.graphics.rectangle('fill', hpBarX, hpBarY, hpBarWidth, hpBarHeight)
  
  
  local hpRatio = PLAYER.hp / PLAYER.hpMax
  love.graphics.setColor(1 - hpRatio, hpRatio, 0)
  love.graphics.rectangle('fill', hpBarX, hpBarY, hpBarWidth * hpRatio, hpBarHeight)
  
  
  love.graphics.setColor(1, 1, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', hpBarX, hpBarY, hpBarWidth, hpBarHeight)

  love.graphics.setColor(1,1,1)
  love.graphics.setFont(fontSmall)
  love.graphics.print("HP: " .. PLAYER.hp .. "/" .. PLAYER.hpMax, 10, 10)
  love.graphics.print("Pattern: " .. attackPatterns[currentPattern], 10, 30)
  love.graphics.print("Box: " .. math.floor(BOARD.w) .. "x" .. math.floor(BOARD.h), 10, 50)
  love.graphics.print("AGGRESSIVE MODE - Spawn: " .. string.format("%.1f", spawnInterval), 10, 70)
  if patternCooldown > 0 then
    love.graphics.print("Cooldown: " .. string.format("%.1f", patternCooldown), 10, 90)
  end
  
  
  love.graphics.print("Music: " .. (sounds.music and "ON" or "MISSING"), 10, 110)
  love.graphics.print("SFX: " .. ((sounds.gaster_charge and sounds.hit) and "ON" or "MISSING"), 10, 130)
  
  love.graphics.print("R - Restart | P - Pause | F11 - Fullscreen", 10, love.graphics.getHeight() - 50)
  love.graphics.print("1/2/3 - Test Sounds | [/] - Volume", 10, love.graphics.getHeight() - 30)
  
  if gameOver then
    love.graphics.setColor(1,0,0)
    love.graphics.setFont(fontLarge)
    love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), 'center')
    love.graphics.setFont(fontSmall)
    love.graphics.printf("Press R to restart", 0, love.graphics.getHeight()/2 + 30, love.graphics.getWidth(), 'center')
  end
  
  love.graphics.pop()
end