local Queue = class("Queue")

function Queue:initialize()
    self._data = {}
    self._front = 1 -- decreases on push
    self._back = 0 -- increases on push
end

function Queue:push(val)
    self._back = self._back + 1
    self._data[self._back] = val
end

function Queue:pushFront(val)
    self._front = self._front - 1
    self._data[self._front] = val
end

function Queue:peek(offset)
    return self._data[self._front + (offset or 0)]
end

function Queue:peekBack(offset)
    return self._data[self._back - (offset or 0)]
end

function Queue:pop()
    if self._front > self._back then
        error("Queue is empty")
    end
    local val = self._data[self._front]
    self._data[self._front] = nil
    self._front = self._front + 1
    return val
end

function Queue:popBack()
    if self._front > self._back then
        error("Queue is empty")
    end
    local val = self._data[self._back]
    self._data[self._back] = nil
    self._back = self._back - 1
    return val
end

function Queue:size()
    return self._front - self._back + 1
end

function Queue:empty()
    return self._front > self._back
end

function Queue:clear()
    self._data = {}
    self._back = 0
    self._front = -1
end

return Queue
