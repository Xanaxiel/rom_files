LogicManager_Hatred = class("LogicManager_Hatred")
local HatredDuration = 3
function LogicManager_Hatred:ctor()
  self.enemies = {}
end
function LogicManager_Hatred:ForEach(func, args)
  for k, v in pairs(self.enemies) do
    if func(k, v, args) then
      return true
    end
  end
  return false
end
function LogicManager_Hatred:Refresh(creature, time)
  self.enemies[creature] = time
end
function LogicManager_Hatred:Remove(creature)
  self.enemies[creature] = nil
end
function LogicManager_Hatred:Update(time, deltaTime)
  local flagTime = time - HatredDuration
  for k, v in pairs(self.enemies) do
    if v < flagTime then
      self.enemies[k] = nil
      k:HatredTimeout()
    end
  end
end
