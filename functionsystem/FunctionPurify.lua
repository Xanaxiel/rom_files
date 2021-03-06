FunctionPurify = class("FunctionPurify")
function FunctionPurify.Me()
  if nil == FunctionPurify.me then
    FunctionPurify.me = FunctionPurify.new()
  end
  return FunctionPurify.me
end
function FunctionPurify:ctor()
  self.timeTick = TimeTickManager.Me():CreateTick(0, 100, self.RefreshFlagTime, self)
  self:Reset()
end
function FunctionPurify:Reset()
  self.running = false
  self.monsters = {}
  self.dropItems = {}
  self.monsterPurifyFlag = {}
end
function FunctionPurify:MonsterNeedPurify(id)
  return self.monsters[id] ~= nil
end
function FunctionPurify:AddDrops(item)
  local items = self.dropItems[item.sourceID]
  if items == nil then
    items = {}
    self.dropItems[item.sourceID] = items
  end
  items[#items + 1] = item
end
function FunctionPurify:StartDarkCover(id)
  local monster = SceneNpcProxy.Instance:Find(id)
  if monster then
  end
end
function FunctionPurify:StartPurifyByServerSkill(data)
  local monsters = {}
  local hits = data.data.hitedTargets
  for i = 1, #hits do
    monsters[#monsters + 1] = hits[i].charid
  end
  self:StartPurify(monsters)
end
function FunctionPurify:StartPurify(monsters)
  if not monsters or #monsters == 0 then
    return
  end
  for i = 1, #monsters do
    self:StartPurifyMonster(monsters[i])
  end
end
function FunctionPurify:TryPurifyMonster(id)
  local simplePlayer = self.monsters[id]
  if simplePlayer then
    simplePlayer.animatorHelper:PlayForce("darklight2", 1)
    self:AddFlag(id)
  end
end
function FunctionPurify:StartPurifyMonster(id)
  local data = self.monsterPurifyFlag[id]
  if data then
    data.confirmPurify = true
    self:CheckCanRealPurify(id, data)
  end
end
function FunctionPurify:AddFlag(id)
  self.monsterPurifyFlag[id] = {time = 0, confirmPurify = false}
  self.timeTick:StartTick()
end
function FunctionPurify:CheckCanRealPurify(id, data)
  if data.confirmPurify and data.time >= 3000 then
    self:RealPurify(id)
  end
end
function FunctionPurify:RealPurify(id)
  local simplePlayer = self.monsters[id]
  if simplePlayer then
    self.monsterPurifyFlag[id] = nil
    function simplePlayer.animatorHelper.loopCountChangedListener(state, oldLoopCount, newLoopCount)
      if state:IsName("darklight3") then
        self:RemoveSimplePlayer(id)
        self:StartDropMonsterItems(id)
        self:RemoveMonster(id)
      end
    end
    simplePlayer.animatorHelper:PlayForce("darklight3", 1)
  end
end
function FunctionPurify:StartDropMonsterItems(id)
  if self.dropItems[id] then
    FunctionSceneItemCommand.Me():DropItems(self.dropItems[id])
    self.dropItems[id] = nil
  end
end
function FunctionPurify:RemoveMonster(id)
  SceneNpcProxy.Instance:RemoveSome({id})
end
function FunctionPurify:RemoveSimplePlayer(id)
  local simplePlayer = self.monsters[id]
  if simplePlayer then
    GameObject.Destroy(simplePlayer.gameObject)
  end
  self.monsters[id] = nil
end
function FunctionPurify:RefreshFlagTime(delta)
  local count = 0
  for k, v in pairs(self.monsterPurifyFlag) do
    count = count + 1
    v.time = v.time + delta
    self:CheckCanRealPurify(k, v)
  end
  if count == 0 then
    self.timeTick:ClearTick()
  end
end
