-- source: https://github.com/kikito/middleclass

local idx = {
  subclasses = { "<nui.utils.object:subclasses>" },
}

local function __tostring(self)
  return "class " .. self.name
end

local function __call(self, ...)
  return self:new(...)
end

local function create_index_wrapper(class, index)
  if type(index) == "table" then
    return function(self, key)
      local value = self.class.__meta[key]
      if value == nil then
        return index[key]
      end
      return value
    end
  elseif type(index) == "function" then
    return function(self, key)
      local value = self.class.__meta[key]
      if value == nil then
        return index(self, key)
      end
      return value
    end
  else
    return class.__meta
  end
end

local function propagate_instance_property(class, key, value)
  value = key == "__index" and create_index_wrapper(class, value) or value

  class.__meta[key] = value

  for subclass in pairs(class[idx.subclasses]) do
    if subclass.__properties[key] == nil then
      propagate_instance_property(subclass, key, value)
    end
  end
end

local function declare_instance_property(class, key, value)
  class.__properties[key] = value

  if value == nil and class.super then
    value = class.super.__meta[key]
  end

  propagate_instance_property(class, key, value)
end

local function create_class(name, super)
  assert(name, "missing name")

  local meta = {}
  meta.__index = meta

  local class = {
    super = super,
    name = name,
    static = {},

    [idx.subclasses] = setmetatable({}, { __mode = "k" }),

    __meta = meta,
    __properties = {},
  }

  setmetatable(class.static, {
    __index = function(_, key)
      local value = rawget(class.__meta, key)
      if value == nil and super then
        return super.static[key]
      end
      return value
    end,
  })

  setmetatable(class, {
    __call = __call,
    __index = class.static,
    __name = class.name,
    __newindex = declare_instance_property,
    __tostring = __tostring,
  })

  return class
end

---@param name string
local function Object(name)
  local Class = create_class(name)

  ---@return string
  function Class:__tostring()
    return "instance of " .. tostring(self.class)
  end

  ---@return nil
  function Class:init() end -- luacheck: no unused args

  function Class.static:new(...)
    local instance = setmetatable({ class = self }, self.__meta)
    instance:init(...)
    return instance
  end

  ---@param name string
  function Class.static:extend(name) -- luacheck: no redefined
    local subclass = create_class(name, self)

    for key, value in pairs(self.__meta) do
      if not (key == "__index" and type(value) == "table") then
        propagate_instance_property(subclass, key, value)
      end
    end

    function subclass.init(instance, ...)
      self.init(instance, ...)
    end

    self[idx.subclasses][subclass] = true

    return subclass
  end

  return Class
end

return Object
