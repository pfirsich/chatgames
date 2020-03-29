local gui = {}

local inRect = ülp.pointInRect

gui.defaultStyle = {
    hoverBgColor = {0.7, 0.7, 0.7},
    clickedBgColor = {0.3, 0.3, 0.3},
    bgColor = {0.5, 0.5, 0.5},
    clickedOutlineColor = {0.2, 0.2, 0.2},
    outlineColor = {0.2, 0.2, 0.2},
    textPadding = 5,
    textColor = {1.0, 1.0, 1.0},
    textAlign = "center",
}

local Button = class("Button")
gui.Button = Button

Button.defaultWidth = 200
Button.defaultHeight = 60

function Button:initialize(text, width, height, x, y, params)
    params = params or {}
    self.text = text
    self.x = x or 0
    self.y = y or 0
    self.w = width or Button.defaultWidth
    self.h = height or Button.defaultHeight
    self.hovered = false
    self.clicked = false
    self.disabled = false
    self.triggered = false
    self.callback = params.callback
    self.style = params.style
end

function Button:update(dt, mouseState)
    self.hovered = inRect(mouseState.x, mouseState.y,
        self.x, self.y, self.w, self.h)
    if self.hovered and mouseState.pressed then
        self.clicked = mouseState.pressed
    end
    self.triggered = false
    if not mouseState.down then
        if not self.disabled and self.clicked and self.hovered then
            self.triggered = true
            if self.callback then
                self:callback()
            end
        end
        self.clicked = false
    end
end

function Button:draw(style)
    if self.style then
        style = self.style
    end

    if self.disabled or self.clicked then
        lg.setColor(style.clickedBgColor)
    elseif self.hovered then
        lg.setColor(style.hoverBgColor)
    else
        lg.setColor(style.bgColor)
    end
    lg.rectangle("fill", self.x, self.y, self.w, self.h)
    if self.clicked or self.disabled then
        lg.setColor(style.clickedOutlineColor)
    else
        lg.setColor(style.outlineColor)
    end
    lg.rectangle("line", self.x, self.y, self.w, self.h)

    local textX = self.x + style.textPadding
    local fontH = lg.getFont():getHeight()
    local textY = math.floor(self.y + self.h / 2 - fontH / 2)
    lg.setColor(style.textColor)
    lg.printf(self.text, textX, textY,
        self.w - style.textPadding * 2, style.textAlign or "center")
end

local Label = class("Label")
gui.Label = Label

function Label:initialize(text, x, y)
    self.text = text
    self.x = x or 0
    self.y = y or 0
end

function Label:update()
end

function Label:draw(style)
    lg.setColor(style.textColor)
    lg.print(self.text, self.x, self.y)
end

function gui.update(widgets, dt, mx, my, mouseDown)
    mouseDown = mouseDown or love.mouse.isDown(1)
    local _mx, _my = love.mouse.getPosition()
    mx = mx or _mx
    my = my or _my

    local mouseState = {
        x = mx, y = my,
        down = mouseDown,
        pressed = mouseDown and not widgets._lastMouseDown,
        released = not mouseDown and widgets._lastMouseDown,
    }

    for i, widget in ipairs(widgets) do
        widget:update(dt, mouseState)
    end

    widgets._lastMouseDown = mouseDown
end

function gui.draw(widgets, style)
    style = style or gui.defaultStyle
    for i, widget in ipairs(widgets) do
        widget:draw(style)
    end
end

return gui