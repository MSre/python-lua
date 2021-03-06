--[[
    Begin the lua pythonization.
--]]

-- overwriting type so we can type dicts and lists etc.
rawtype = type
function type(obj)
    local t = rawtype(obj)
    if (t == 'table') then
        local mt = getmetatable(obj)
        if (mt ~= nil) then            
            if (mt.__type and rawtype(mt.__type) == "function") then
                return getmetatable(obj).__type(obj)
            elseif (mt.__type and rawtype(mt.__type) == "table") then
                return getmetatable(obj).__type
            end
            return getmetatable(obj).__type or t
        end
    end
    return t
end

function isinstance(obj,typ)
    if (typ == int or typ == float) then
        typ = "number"
    elseif (typ == str) then
        typ = "string"
    end
    if rawtype(typ) == "table" then
        -- here we should also check for types of _bases
        ret = getmetatable(typ).__type or "table"
        return type(obj) == ret
    end
    return type(obj) == typ
end
-- String functions
local string_meta = getmetatable("")
string_meta.__add = function(v1, v2)
    if type(v1) == "string" and type(v2) == "string" then
        return v1 .. v2
    end
    return v1 + v2
end
string_meta.__index = function(str,key)
    if type(key) == slice then
        return key:process(str)
    end
    if rawtype(key) == "number" then
        return string.sub(str, key+1, key+1)
    end
    return string[key]
end
function string.replace(str,old,new,count)
    str, _ = string.gsub(str,old,new,count)
    return str
end
oldfind = string.find
function string.find(str,search,from)
    index, _ = oldfind(str,search,from,true)
    if index ~= nil then
        return index - 1
    end
    return index
end
string.index = string.find
oldformat = string.format
function string.format(str,...)
    for _,j in ipairs({...}) do
        str = str:gsub("{.-}",j,1)
    end
    return str
end

function string.split(str,spl)
    lst = list {}
    f = str:find(spl)
    s = 0
    while f ~= nil do
        lst:append(str:sub(s+1,f))
        s = f + #spl
        f = str:find(spl,s+1)
        
    end
    lst:append(str:sub(s+1))
    return lst
end
function string.join(str,lst)
    nstr = ""
    l = len(lst)-1 
    for i,item in enumerate(lst) do
        if i == l then
            nstr = nstr .. item
        else
            nstr = nstr .. item .. str
        end
    end
    return nstr
end


local g_real_unpack = unpack or table.unpack

unpack = function(t)
    if type(t) == list then
        return g_real_unpack(t._data)
    end
    return g_real_unpack(t)
end

abs = math.abs
ascii = string.byte
chr = string.char
int = tonumber
float = tonumber
str = tostring
coroutine.pause = coroutine.yield

function all(iterable)
    for element in iterable do
        if not element then
            return false
        end
    end
    return true
end

function any(iterable)
    for element in iterable do
        if element then
            return true
        end
    end
    return false
end

function bool(x)
    if x == false or x == nil or x == 0 then
        return false
    end

    if type(x) == list or type(x) == dict then
        return next(x._data) ~= nil
    end

    return true
end 

function callable(x)
    local x_type = rawtype(x)
    if x_type == "function" then
        return true
    end
    if x_type == "table" and type(x) ~= list and type(x) ~= dict then
        local meta = getmetatable(x)
        if meta == nil then return false end
        return rawtype(meta.__call) == "function" 
    end

    return false
end

function divmod(a, b)
    local res = { math.floor(a / b), math.fmod(a, b) }
    return unpack(res)
end

function len(t)
    if type(t._data) == "table" then
        return #t._data
    end

    return #t
end

function range(from, to, step)
    assert(from ~= nil)
    
    if to == nil then
        to = from
        from = 0        
    end

    step = step or 1

    local i = from
    
    return function()
        ret = i
        if (step > 0 and i >= to) or (step < 0 and i <= to) then
            return nil
        end
        
        i = i + step
        return ret
    end
end


function enumerate(t, start)
    start = start or 0

    local data = t
    if type(t) == list then
        data = t._data
    end

    local i, v = next(data, nil)
    return function()
        local index, value = i, v
        i, v = next(data, i)

        if index == nil then
            return nil
        end

        return index + start - 1, value
    end
end

function hasattr(obj, attr)
    return (obj[attr] ~= nil)
end
function getattr(obj, attr)
    return obj[attr]
end
function setattr(obj, attr, v)
    obj[attr] = v
end
function delattr(obj, attr)
    obj[attr] = nil
end

tuple = {}
setmetatable(tuple, {
    __call = function(_, t)
        local result = {}

        result._data = {}
        for _, v in ipairs(t) do
            table.insert(result._data, v)
        end
    
        local methods = {}

        methods.index = function(value, start, enda)
            start = start or 1
            enda = enda or #result._data

            for i = start, enda, 1 do
                if result._data[i] == value then
                    return i
                end
            end

            return nil
        end

        methods.count = function(value)
            local cnt = 0
            for _, v in ipairs(result._data) do
                if v == value then
                    cnt = cnt + 1
                end
            end

            return cnt
        end

        local iterator_index = nil
        setmetatable(result, {
            __index = function(self, index)
                if type(index) == "number" then
                    if index < 0 then
                        index = #result._data + index
                    end
                    return rawget(result._data, index + 1)
                elseif type(index) == slice then
                    return index:process(self)
                end
                return _stripself(methods[index])
            end,
            __newindex = function(self, index, value)                
                error("Attempt to set index in tuple.")
            end,
            __call = function(self, _, idx)
                if idx == nil and iterator_index ~= nil then
                    iterator_index = nil
                end

                local v = nil
                iterator_index, v = next(result._data, iterator_index)

                return v
            end,
            __type = tuple,
            __tostring = function(self)
                local str = "("
                for i,v in ipairs(self._data) do
                    if i < #self._data then
                        str = str .. tostring(v) .. ", "
                    else
                        str = str .. tostring(v)
                    end
                end
                return str .. ")"
            end
        })
        return result
    end,
    __type = tuple,
    __tostring = function(self)
        return "tuple"
    end
})

list = {}
setmetatable(list, {
    __call = function(_, t)
        local result = {}

        if isinstance(t,tuple) or isinstance(t,list) then
            result._data = {}
            for _, v in ipairs(t._data) do
                table.insert(result._data, v)
            end
        else
            result._data = {}
            for _, v in ipairs(t) do
                table.insert(result._data, v)
            end
        end
        local methods = {}

        methods.append = function(value)
            table.insert(result._data, value)
        end

        methods.extend = function(iterable)
            for value in iterable do
                table.insert(result._data, value)
            end
        end

        methods.insert = function(index, value)
            table.insert(result._data, index+1, value)
        end

        methods.remove = function(value)
            for i, v in ipairs(result._data) do
                if value == v then
                    table.remove(result._data, i)
                    break
                end
            end
        end

        methods.pop = function(index)
            index = index or (#result._data-1)
            local value = result._data[index+1]
            table.remove(result._data, index+1)
            return value
        end

        methods.clear = function()
            result._data = {}
        end

        methods.index = function(value, start, enda)
            start = start or 1
            enda = enda or #result._data

            for i = start, enda, 1 do
                if result._data[i] == value then
                    return i
                end
            end

            return nil
        end

        methods.count = function(value)
            local cnt = 0
            for _, v in ipairs(result._data) do
                if v == value then
                    cnt = cnt + 1
                end
            end

            return cnt
        end

        methods.sort = function(key, reverse)
            key = key or nil
            reverse = reverse or false

            table.sort(result._data, function(a, b)
                if reverse then
                    return a < b
                end

                return a > b
            end)
        end

        methods.reverse = function()
            local new_data = {}
            for i = #result._data, 1, -1 do
                table.insert(new_data, result._data[i])
            end

            result._data = new_data
        end

        methods.copy = function()
            return list(result._data)
        end

        local iterator_index = nil
        setmetatable(result, {
            __index = function(self, index)
                if type(index) == "number" then
                    if index < 0 then
                        index = #result._data + index
                    end
                    return rawget(result._data, index + 1)
                elseif type(index) == slice then
                    return index:process(self)
                end
                return _stripself(methods[index])
            end,
            __newindex = function(self, index, value)
                table.remove(result._data, index+1)
                table.insert(result._data, index+1, value)
            end,
            __call = function(self, _, idx)
                if idx == nil and iterator_index ~= nil then
                    iterator_index = nil
                end

                local v = nil
                iterator_index, v = next(result._data, iterator_index)

                return v
            end,
            __type = list,
            __tostring = function(self)
                local str = "["
                for i,v in ipairs(self._data) do
                    if i < #self._data then
                        str = str .. tostring(v) .. ", "
                    else
                        str = str .. tostring(v)
                    end
                end
                return str .. "]"
            end
        })
        return result
    end,
    __type = list,
    __tostring = function(self)
        return "list"
    end
})

dict = {}
setmetatable(dict, {
    __call = function(_, t)
        local result = {}

        result._data = {}
        for k, v in pairs(t) do
            result._data[k] = v
        end

        local methods = {}

        local key_index = nil

        methods.clear = function()
            result._data = {}
        end

        methods.copy = function()
            return dict(result._data)
        end

        methods.get = function(key, default)
            default = default or nil
            if result._data[key] == nil then
                return default
            end

            return result._data[key]
        end

        methods.items = function()
            return pairs(result._data)
        end

        methods.keys = function()
            return function(self, idx, _) 
                if idx == nil and key_index ~= nil then
                    key_index = nil
                end

                key_index, _ = next(result._data, key_index)
                return key_index
            end
        end

        methods.pop = function(key, default)
            default = default or nil
            if result._data[key] ~= nil then
                local value = result._data[key]
                result._data[key] = nil 
                return key, value
            end

            return key, default
        end

        methods.popitem = function()
            local key, value = next(result._data)
            if key ~= nil then
                result._data[key] = nil
            end

            return key, value
        end

        methods.setdefault = function(key, default)
            if result._data[key] == nil then
                result._data[key] = default
            end

            return result._data[key]
        end

        methods.update = function(t)
            assert(type(t) == dict)

            for k, v in t.items() do
                result._data[k] = v
            end
        end

        methods.values = function()
            return function(self, idx, _) 
                if idx == nil and key_index ~= nil then
                    key_index = nil
                end

                key_index, value = next(result._data, key_index)
                return value
            end
        end

        setmetatable(result, {
            __index = function(self, index)
                if result._data[index] ~= nil then
                    return result._data[index]
                end
                return _stripself(methods[index])
            end,
            __newindex = function(self, index, value)
                result._data[index] = value
            end,
            __call = function(self, _, idx)
                if idx == nil and key_index ~= nil then
                    key_index = nil
                end

                key_index, _ = next(result._data, key_index)

                return key_index            
            end,
            __type = dict,
            __tostring = function(self)
                local str = ""
                for k,v in pairs(self._data) do
                    if (str == "") then
                        str = "{ " .. tostring(k) .. ": " .. tostring(v)
                    else
                        str = str .. ", " .. tostring(k) .. ": " .. tostring(v)
                    end
                end
                return str .. " }"
            end
        })
        
        return result
    end,
    __type = dict,
    __tostring = function(self)
        return "dict"
    end
})

function staticmethod(old_fun)
    return old_fun
end
-- make an object with all redirected functions to avoid taking up memory
_strippedmethods = {}
function _stripself(old_fun)
    if not _strippedmethods[old_fun] then
        _strippedmethods[old_fun] = function(self,...) return old_fun(...) end
    end
    return _strippedmethods[old_fun]
end

function operator_in(item, items)
    if type(items) == list or type(items) == dict then
        for v in items do
            if v == item then
                return true
            end
        end
    elseif type(items) == "string" and type(item) == "string" then
        return oldfind(items, item, 1, true) ~= nil
    elseif rawtype(items) == "table" then
        if callable(getmetatable(items).__in) then
            return getmetatable(items).__in(items,item)
        end
    end
    return false
end

-- Lua classes
object = {
    __new__ = function(self,cls)
        return {}
    end
}

function class(class_init, name, bases, mtmethods, properties)
    bases = bases or {}
    local c = {}
    -- add the attributes, properties and metamethods by inheritance
    c.properties = {}
    c.attrs = {}
    c.mtmethods = {}
    for _, base in ipairs(bases) do
        for k, v in pairs(base.attrs) do
            c.attrs[k] = v
        end
        for k, v in pairs(base.properties) do
            c.properties[k] = v
        end
        for k, v in pairs(base.mtmethods) do
            c.mtmethods[k] = v
        end
    end
    c._bases = bases

    -- initialize the attributes, properties and metamethods
    c.attrs = class_init(c.attrs)
    for k,v in pairs(properties) do
        c.properties[k] = v
    end
    for k,v in pairs(mtmethods) do
        c.mtmethods[k] = v
    end

    -- premake the instance metatable to be set on every object
    local imt = {}
    imt.__type = c
    imt.__tostring = function(self)
        return self._hashid
    end
    for k,v in pairs(c.mtmethods) do
        imt[k] = c.attrs[v]
    end
    imt.__index = function(tbl, idx)
        local attr = c.attrs[idx]
        
        if (c.properties[idx]) then
            return attr.gfunc(tbl)
        end
        if attr == nil and idx ~= "__init__" and (callable(c.attrs['__getitem__'])) then
            return c.attrs.__getitem__(tbl,idx)
        end
        return attr
    end
    imt.__newindex = function(tbl, idx, new)
        local attr = c.attrs[idx]
        if (c.properties[idx]) then
            attr.sfunc(tbl,new)
        -- elseif attr == nil and callable(c.attrs['__setitem__']) then
        --     c.attrs.__setitem__(tbl,idx,new)
        else
            rawset(tbl,idx,new)
        end
    end

    -- class definition metatable, referred to on the class object, not instances
    local mt = getmetatable(c) or {}
    mt.__call = function(_, ...)
        local o = nil
        -- check the new method, to know if we should allocate a new table
        if c.attrs.__new__ ~= nil then
            o = c.attrs.__new__(c,...)
            if o == nil then
                return nil
            end
            if rawtype(o) == "userdata" then
                return o
            end
        else
            o = {}
        end
        -- if the object is old, don't reset the metatable, otherwise set the instance metatable
        if getmetatable(o) == nil then
            o._hashid = tostring(c) .. "<" .. tostring(o):gsub("table: ", "", 1) .. ">"
            setmetatable(o, imt)
        end
        -- initialize the object if it has the init function
        if type(o.__init__) == "function" then
            o:__init__(...)
        end
        return o
    end
    mt.__type = c
    mt.__index = function(self,key)
        if type(c.attrs[key]) == "function" then
            return _stripself(c.attrs[key])
        else
            return c.attrs[key]
        end
    end
    mt.__newindex = function(self,key,value)
        c.attrs[key] = value
    end
    mt.__tostring = function(self) 
        return name   -- perhaps it is better if the type table is not the main object, but instead a separate table? the __tostring of the main object might be confusing.
    end
    setmetatable(c, mt)

    -- attributes metatable for redirecting calls
    amt = {}
    amt.__type = c
    amt.__call = function(...)
        return mt.__call(...)
    end
    setmetatable(c.attrs,amt)

    return c
end
-- properties implemented by class object / decorator. Requires as well a properties list
-- on the main class for __index and __newindex referral.
property = class(function(property)
    function property.__init__(self,gfunc,sfunc)
        rawset(self,"gfunc",gfunc)
        rawset(self,"sfunc",sfunc)
    end
    function property.getter(self,gfunc)
        rawset(self,"gfunc",gfunc)
        return self
    end
    function property.setter(self,sfunc)
        rawset(self,"sfunc",sfunc)
        return self
    end
    return property
end, "property", {}, {}, {})

slice = class(function(slice)
    function slice.__init__(self,lower,upper,step)
        if lower == nil then
            self.lower = nil
        else
            self.lower = lower+1
        end
        self.upper = upper
        self.step = step
    end
    function slice.process(self,obj)
        start = self.lower
        stop = self.upper
        if start == nil then start = 1 end
        if stop == nil then stop = len(obj) end
        if type(obj) == "string" then
            return obj:sub(start,stop)
        elseif type(obj) == list then
            nobj = list {}
            start = self.lower
            stop = self.upper
            if start == nil then start = 1 end
            if stop == nil then stop = len(obj) end
            for i in range(start-1,stop) do
                nobj:append(obj[i])
            end
            return nobj
        end
    end
    return slice
end, "slice", {}, {}, {})


--[[
    End of the lua pythonization.
--]]
