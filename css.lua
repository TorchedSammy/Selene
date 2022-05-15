-- stolen

-- returns a bool saying whether a selector
-- is known or not (single colon, things like hover or focus)
local function knownSingleSelector(selector)
   -- there's more but i'll only add if someone wants to use them
   local selectors = {
      'active',
      'checked',
      'default',
      'disabled',
      'empty',
      'enabled',
      'focus',
      'fullscreen',
      'hover',
      'invalid',
      'link',
      'optional',
      'root',
      'target',
      'valid',
      'visited',
   }
   for _, sel in ipairs(selectors) do
      if sel == selector then return true end
   end

   return false
end

local function side_str (side)
   if side then return '-'..side else return '' end
end

-- make numbers into pixel sizes
local function size_str (size)
   if type(size) == 'number' then
      return size..'px'
   elseif type(size) == 'string' then
      return size
   else
      error 'size must be number or string'
   end
end

-- has a table only got keys with names of sides?
local sides = {
   left = true,
   right = true,
   bottom = true,
   top = true
}

function has_sides (t)
   local ok = false
   for k in pairs(t) do
      if not sides[k] then return false end
      ok = true
   end
   return ok
end

-- border
--  border = true
--  border = {width=3}
--  border = {left={color='#999'}}
function set_border (tbl,side,t)
   t = t or {}
   t.width = t.width or '1px'
   t.style = t.style or 'solid'
   t.color = t.color or '#0000'
   side = side_str(side)
   local border = 'border'..side..'-'
   tbl[border..'width'] = t.width
   tbl[border..'style'] = t.style
   tbl[border..'color'] = t.color
end

function process_border (tbl,spec,side)
   if spec == true then -- defaults
      set_border(tbl,side)
   elseif type(spec) == 'table' then
      if not has_sides(spec) then
         set_border(tbl,side,spec)
      else
         for side, sspec in pairs(spec) do
            process_border(tbl,sspec,side)
         end
      end
   end
end

-- margins or padding
--  margin = 4
--  margin = {left=2, right=4}
function process_margin_or_padding (tbl,which,spec,side)
   if type(spec) ~= 'table' then
      tbl[which..side_str(side)] = size_str(spec)
   elseif has_sides(spec) then
      for side, sspec in pairs(spec)do
         process_margin_or_padding(tbl,which,sspec,side)
      end
   else
      error('must contain only top, left, right and bottom keys')
   end
end

function css_body (self,spec)
   self:write '{\n'
   local processed = {}
   for prop, val in pairs(spec) do
      if prop == 'border' then
         process_border(processed,val)
      elseif prop == 'margin' or prop == 'padding' then
         process_margin_or_padding(processed,prop,val)
      else
         if type(val) == 'number' then
             val = size_str(val)
         end
         processed[prop] = val
      end
   end
   for prop, val in pairs(processed) do
      if type(prop) == 'string' then
         prop = prop:gsub('_','-')
         if type(val) == 'table' or type(val) == 'function' then val = '' end
         self:write('\t'..prop..': '..val..';\n')
      end
   end
   self:write '}\n'
end


function css_ (self,selector, select2)
   if type(selector) == 'string' then
      self:write(selector..' ')
      return function(spec)
         css_body(self,spec)
      end
   else
      local spec = selector
      if spec ~= css then
         local ss, append = {}, table.insert
         for i,s in ipairs(self.ss) do
            if s == 'id' then
               append(ss,'#')
            elseif s == 'class' then
               append(ss,'.')
            else
               append(ss,s)
               if self.ss[i+1] ~= 'class' then
                  append(ss,' ')
               end
            end
         end
         selector = table.concat(ss)
         self.ss = {}
         self:write(selector)
         css_body(self,spec)
      else
         spec = select2
         local ss, append = {}, table.insert
         for i,s in ipairs(self.ss) do
            if s == 'id' then
               append(ss,'#')
            elseif s == 'class' then
               append(ss,'.')
            elseif knownSingleSelector(s) then
               local sel = s:gsub('_', '-')
               append(ss, ':' .. sel)
            else
               append(ss,s)
               if self.ss[i+1] ~= 'hover' then
                  append(ss,' ')
               end
            end
         end
         selector = table.concat(ss)
         self.ss = {}
         self:write(selector..' ')
         css_body(self, spec)
      end
   end
end

css = {
   ss={};
   write = function(self,text) -- we are a rope!
      self[#self+1] = text
   end;
   clear = function()
      css.ss = {}
      while table.remove(css) do end
   end;
   empty = function(val)
      if not val or val == '' then return nil end
      return val
   end;
}

setmetatable(css,{
   -- the Dot Builder pattern
   __index = function(self,key)
      local b = self.ss
      b[#b+1] = key
      return self
   end;
   __tostring = table.concat, -- we are a rope!
   __call = css_
})

return css

