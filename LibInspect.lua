--[[
type:
    all - use sparingly because achivements look havy
    items - returns a table of items
    honor - not yet
    talents - not yet
    achivements - not yet

Methods:
success = LibInspect:AddHook('MyAddon', type, function(guid, data, age) YourFunction(guid, data, age); end);
maxAge = LibInspect:SetMaxAge(seconds);
caninspect, unitfound, refreshing = LibInspect:RequestData(type, target, force);
    or LibInspect:Request_Type_(target, force) ex. LibInspect:RequestItems(...)

Callbacks:
    When the data is ready you YourFunction(guid, data, age) will be called
    
    guid = UnitGUID(); use this to tie it to the inspect request
    
    data = false or {
        items = {
            1 = itemLink,
            2 = itemLink,
            ...
            18 = itemLink,
        },
        honor = ...,
        talents = ...,
        achivements = ...,
    }
    
    age = ##; how old in seconds the data is
]]

-- Start the lib
local lib = LibStub:NewLibrary('LibInspect', 1);
if not lib then return end
if not lib.frame then lib.frame = CreateFrame("Frame"); end

lib.maxAge = 1800; -- seconds
lib.rescan = 8; -- What to consider min items
lib.rescanGUID = 0; -- GUID for 2nd pass scanning
lib.cache = {};
lib.hooks = {
    items = {},
    honor = {},
    talents = {},
    achievemnts = {},
};

lib.events = {
    items = "INSPECT_READY",
    honor = "INSPECT_HONOR_UPDATE",
    achievemnts = "INSPECT_ACHIEVEMENT_READY",
}

-- 
function lib:AddHook(addon, what, callback)
    if addon and what and callback then
        if type(what) == 'string' then
            if what == 'all' then
                local i = self:SecureAddHook(addon, 'items', callback);
                local h = self:SecureAddHook(addon, 'honor', callback);
                local t = self:SecureAddHook(addon, 'talents', callback);
                local a = self:SecureAddHook(addon, 'achievemnts', callback);
                
                if i and h and t and a then
                    return true;
                else
                    return false, i, h, t, a;
                end
            elseif what == 'items' then
                return self:SecureAddHook(addon, 'items', callback);
            elseif what == 'honor' then
                return self:SecureAddHook(addon, 'honor', callback);
            elseif what == 'talents' then
                return self:SecureAddHook(addon, 'talents', callback);
            elseif what == 'achievemnts' then
                return self:SecureAddHook(addon, 'achievemnts', callback);
            else
                --- print('LibInspect:AddHook Unkown Type '..what);
                return false;
            end
        end
    else
        --- print('LibInspect:AddHook Missing Variable ', addon, what, callback);
        return false;
    end
end

-- Internal only, should prob be local
function lib:SecureAddHook(addon, what, callback)
    if self.hooks[what] then
        self.hooks[what][addon] = callback;
        
        -- Register the event
        if self.events[what] then
            self.frame:RegisterEvent(self.events[what]);
        end
        
        return true;
    else
        --- print('LibInspect:SecureAddHook Unkown Type ', addon, what, callback);
        return false;
    end
end

function lib:RemoveHook(addon, what)
    if addon then
        if not what then what = 'all'; end
        
        if what == 'all' then
            self:RemoveHook(addon, 'items');
            self:RemoveHook(addon, 'honor');
            self:RemoveHook(addon, 'talents');
            self:RemoveHook(addon, 'achievemnts');
        elseif what == 'items' or what == 'honor' or what == 'talents' or what == 'achievemnts' then
            self.hooks[what][addon] = false;
            
            -- Clean up events if we can
            if self:count(self.hooks[what]) == 0 and self.events[what] then
                self.frame:UnregisterEvent(self.events[what]);
            end
        else
            --- print('LibInspect:RemoveHook Unkown Type ', what);
            return false;
        end
    else
        --- print('LibInspect:RemoveHook No Addon Passed');
        return false;
    end
end

function lib:SetMaxAge(maxAge)
    if ( maxAge < self.maxAge ) then
        self.maxAge = maxAge;
    end
    
    return self.maxAge;
end

function lib:RequestData(what, target, force)
    -- Error out on a few things
    if not target then return false end
    if InCombatLockdown() then return false end
    if not CanInspect(target) then return false end
    
    if not what then what = 'all'; end
    
    -- Manual requests reset the rescan lock
    self.rescanGUID = 0;
    
    -- Make sure they are in cache
    local guid = self:AddCharacter(target);
    
    if guid then
        
        -- First check for cached
        if  self.cache[guid].data == false or self.cache[guid].time == 0 or (time() - self.cache[guid].time) > self.maxAge or force then
            
            self.cache[guid].target = target;
            
            if what == 'all' then
                self:SafeRequestItems(target);
                self:SafeRequestHonor(target);
                self:SafeRequestTalents(target);
                self:SafeRequestAchivements(target);
            elseif what == 'items' then
                self:SafeRequestItems(target);
            elseif what == 'honor' then
                self:SafeRequestHonor(target);
            elseif what == 'talents' then
                self:SafeRequestTalents(target);
            elseif what == 'achivements' then
                self:SafeRequestAchivements(target);
            else
                --- print('LibInspect:RequestData Unkown Type ', what);
                return false;
            end
            
            return true, true, true;
        else
            if what == 'all' then
                self:RunHooks('items', guid);
                self:RunHooks('honor', guid);
                self:RunHooks('talents', guid);
                self:RunHooks('achivements', guid);
            elseif what == 'items' then
                self:RunHooks('items', guid);
            elseif what == 'honor' then
                self:RunHooks('honor', guid);
            elseif what == 'talents' then
                self:RunHooks('talents', guid);
            elseif what == 'achivements' then
                self:RunHooks('achivements', guid);
            else
                --- print('LibInspect:RequestData Unkown Type ', what);
                return false;
            end
            
            return true, true, false;
        end
    else
        --- print('LibInspect:RequestData AddCharacter failed to turn a guid ', target, guid, ' another go at guid ', UnitGUID(target));
        return true, false;
    end
end

-- Shortcuts
function lib:RequestItems(target, force) return self:RequestData('items', target, force); end
function lib:RequestHonor(target, force) return self:RequestData('items', target, force); end
function lib:RequestTalents(target, force) return self:RequestData('items', target, force); end
function lib:RequestAchivements(target, force) return self:RequestData('achivements', target, force); end

-- Safe Functions for Requests
function lib:SafeRequestItems(target)
    
    -- Fix an inspect frame bug, may be fixed in 4.3
    if InspectFrame then InspectFrame.unit = target; end
    
    NotifyInspect(target);
end

function lib:SafeRequestHonor(target)
    RequestInspectHonorData();
end

function lib:SafeRequestTalents(target)
end

function lib:SafeRequestAchivements(target)
end

function lib:InspectReady(guid)
    -- Few more error checks
    if not guid then return false end
    if InCombatLockdown() then return false end
    
    -- Make sure we have a target
    if self.cache[guid] and self.cache[guid].target then
        local target = self.cache[guid].target;
        
        -- Make sure we can still inspect them still
        if CanInspect(target) then
            self.cache[guid].time = time();
            
            if not self.cache[guid].data then
                self.cache[guid].data = {};
            end
            
            self.cache[guid].data['items'] = {};
            
            local items, count = self:GetItems(target);
            
            -- Do a 2nd pass if there aren't many items
            if self.rescan <= 8 and self.rescanGUID == guid then
                self.rescanGUID = guid;
                NotifyInspect(target);
            end
            
            self.cache[guid].data.items = items;
        end
        
        self:RunHooks('items', guid);
    end
end

function lib:GetItems(target)
    if CanInspect(target) then
        local items = {};
        local count = 0;
        
        for i = 1, 18 do
            local itemLink = GetInventoryItemLink(target, i);
            items[i] = itemLink;
            
            if itemLink then count = count + 1; end
        end
        
        print('GetItems', UnitName(target), count);
        
        return items, count;
    else
        return false;
    end
end


function lib:AddCharacter(target)
    local guid = UnitGUID(target);
    
    if guid then
        -- Set up information
        if not self.cache[guid] then
            self.cache[guid] = {};
            self.cache[guid].data = false;
            self.cache[guid].time = 0;
        end
        
        -- Update target cache
        self.cache[guid].target = target;
        
        -- Return guid to save on calls
        return guid;
    else
        return false;
    end
end

function lib:RunHooks(what, guid)
    for addon,callback in pairs(self.hooks[what]) do
        callback(guid, self.cache[guid].data, time() - self.cache[guid].time);
    end
end

function lib:count(tbl)
    local i = 0;
    
    for k,v in pairs(tbl) do
        i = i + 1;
    end
    
    return i;
end


local function OnEvent(self, event, ...)
    if event == 'INSPECT_READY' then
        lib:InspectReady(...);
    elseif event == 'INSPECT_HONOR_UPDATE' then
        lib:InspectHonorUpdate(...);
    elseif event == 'INSPECT_ACHIEVEMENT_READY' then
        lib:InspectAchievementReady(...);
    end
end

lib.frame:SetScript("OnEvent", OnEvent);