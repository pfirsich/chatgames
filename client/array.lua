local Array = class("Array")

function Array:initialize(self)
	self._data = {}
	self._size = 0
end

function Array:size()
	return self._size
end

function Array:empty()
	return self._size == 0
end

function Array:data()
	return self._data
end

function Array:get(idx)
	return self._data[idx]
end

function Array:set(idx, val)
	self._data[idx] = val
end

function Array:append(val)
	self._data[self._size + 1] = val
	self._size = self._size + 1
end

function Array:insert(idx, val)
	for i = self._size, idx, -1 do
		self._data[i+1] = self._data[i]
	end
	self._data[idx] = val
end

function Array:clear()
	self._data = {}
	self._size = 0
end

function Array:truncate(size)
	self._size = size
end

local function iter(array, idx)
	idx = idx + 1
	if idx <= array._size then
		return idx, array._data[idx]
	end
end

function Array:iter()
	return iter, self, 0
end

return Array