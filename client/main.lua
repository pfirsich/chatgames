require("globals")
require("libs.strict")

local net = require("net")
local scenes = require("scenes")

function love.load(arg)
    if not DEVMODE then
        ülp.autoFullscreen()
    end

    scenes.require()
    for name, scene in pairs(scenes) do
        scene.realTime = 0
        scene.simTime = 0
        scene.frameCounter = 0
        ülp.call(scene.load)
    end

    scenes.enter(scenes.createJoinLobby)
end

function love.keypressed(key)
    local ctrl = lk.isDown("lctrl") or lk.isDown("rctrl")

    if DEVMODE and key == "f11" then
        ülp.autoFullscreen()
    end
end

function love.run()
    love.load(love.arg.parseGameArguments(arg), arg)

    -- We don't want the first frame's dt to include time taken by love.load.
    lt.step()

    local dt = 0
    local fixedDt = 1.0/60.0

    return function()
        local scene = scenes.current
        while scene.simTime <= scene.realTime do
            scene.simTime = scene.simTime + fixedDt
            scene.frameCounter = scene.frameCounter + 1

            if love.event then
                love.event.pump()
                for name, a,b,c,d,e,f in love.event.poll() do
                    if name == "quit" then
                        if not love.quit or not love.quit() then
                            ülp.call(scene.exit)
                            return a or 0
                        end
                    end

                    love.handlers[name](a, b, c, d, e, f)
                    ülp.call(scene[name], a, b, c, d, e, f)
                end
            end

            ülp.call(scene.tick, fixedDt)
        end

        dt = lt.step()

        scene.realTime = scene.realTime + dt

        if lg and lg.isActive() then
            lg.origin()
            lg.clear(lg.getBackgroundColor())
            scene.draw(dt)
            if DEVMODE then
                lg.print(tostring(lt.getFPS()), 5, 5)
            end
            lg.present()
        end

        lt.sleep(0.001)
    end
end
