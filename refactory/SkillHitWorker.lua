SkillHitWorker = class("SkillHitWorker", ReusableObject)
if not SkillHitWorker.SkillHitWorker_Inited then
  SkillHitWorker.SkillHitWorker_Inited = true
  SkillHitWorker.PoolSize = 200
end
local DamageType = CommonFun.DamageType
local FindCreature = SceneCreatureProxy.FindCreature
local tempVector3 = LuaVector3.zero
local tempVector3_1 = LuaVector3.zero
local tempList = {}
local SpecialHitEffectTypes = {HitEffectMove = 1, MultiTargetConnect = 2}
local CreateShareDamageInfos = function(origin, infos)
  if nil ~= origin and #origin > 0 then
    if nil == infos then
      infos = ReusableTable.CreateArray()
    end
    TableUtility.ArrayShallowCopyWithCount(infos, origin, origin[1] * 3 + 1)
  elseif nil ~= infos then
    DestroyShareDamageInfos(infos)
    infos = nil
  end
  return infos
end
local DestroyShareDamageInfos = function(infos)
  if nil ~= infos then
    ReusableTable.DestroyArray(infos)
  end
end
function SkillHitWorker.Create(args)
  return ReusableObject.Create(SkillHitWorker, true, args)
end
function SkillHitWorker:ctor()
  self.args = {
    [1] = nil,
    [2] = LuaVector3.zero,
    [3] = 0,
    [4] = 0,
    [5] = nil,
    [6] = nil,
    [7] = 0
  }
end
function SkillHitWorker:AddRef()
  self.ref = self.ref + 1
end
function SkillHitWorker:SubRef()
  self.ref = self.ref - 1
  if self.ref <= 0 then
    self:Destroy()
  end
end
function SkillHitWorker:Init(skillInfo, fromPosition, fromGUID, fromWeaponID)
  local args = self.args
  if 0 ~= args[7] then
    return
  end
  args[1] = skillInfo
  args[2]:Set(fromPosition[1], fromPosition[2], fromPosition[3])
  args[3] = fromGUID
  args[4] = fromWeaponID
  args[5] = nil
  args[6] = nil
  args[7] = 0
end
function SkillHitWorker:GetSkillInfo()
  return self.args[1]
end
function SkillHitWorker:GetFromGUID()
  return self.args[3]
end
function SkillHitWorker:SetFromPosition(p)
  self.args[2]:Set(p[1], p[2], p[3])
end
function SkillHitWorker:SetForceEffectPath(effectPath)
  self.args[5] = effectPath
end
function SkillHitWorker:AddTarget(targetGUID, damageType, damage, shareDamageInfos, comboDamageLabel)
  local args = self.args
  local targetCount = args[7]
  local index = 7 + targetCount * 5
  args[7] = targetCount + 1
  args[index + 1] = targetGUID
  args[index + 2] = damageType
  args[index + 3] = damage
  args[index + 4] = CreateShareDamageInfos(shareDamageInfos, args[index + 4])
  args[index + 5] = comboDamageLabel
end
function SkillHitWorker:SetTargetComboDamageLabel(index, comboDamageLabel)
  local args = self.args
  index = 7 + (index - 1) * 5
  local oldLabel = args[index + 5]
  if oldLabel == comboDamageLabel then
    return
  end
  args[index + 5] = comboDamageLabel
  if self.delayed then
    if nil ~= oldLabel then
      oldLabel:SubRef()
    end
    if nil ~= comboDamageLabel then
      comboDamageLabel:AddRef()
    end
  end
end
function SkillHitWorker:GetTargetCount()
  return self.args[7]
end
function SkillHitWorker:GetTarget(index)
  local args = self.args
  index = 7 + (index - 1) * 5
  return args[index + 1], args[index + 2], args[index + 3], args[index + 4], args[index + 5]
end
function SkillHitWorker:Work(damageIndex, damageCount, forceSingleDamage)
  local args = self.args
  local targetCount = args[7]
  if targetCount <= 0 then
    return
  end
  local creature = FindCreature(args[3])
  self:_Work(creature, args[8], args[9], SkillLogic_Base.GetSplitDamage(args[10], damageIndex, damageCount), args[11], args[12], forceSingleDamage, 1, targetCount)
  tempList[#tempList + 1] = args[8]
  local subCount = targetCount - 1
  if subCount > 0 then
    local effectPath = args[5]
    args[5] = nil
    for i = 1, subCount do
      local index = 7 + i * 5
      self:_Work(creature, args[index + 1], args[index + 2], SkillLogic_Base.GetSplitDamage(args[index + 3], damageIndex, damageCount), args[index + 4], args[index + 5], forceSingleDamage, i + 1, targetCount)
      tempList[#tempList + 1] = args[index + 1]
    end
    args[5] = effectPath
  end
  self:_MultiSpecialHit(tempList)
  TableUtility.ArrayClear(tempList)
end
function SkillHitWorker:_Work(creature, targetGUID, damageType, damage, shareDamageInfos, comboDamageLabel, forceSingleDamage, targetIndex, targetCount)
  local args = self.args
  local targetCreature = FindCreature(targetGUID)
  if nil == targetCreature then
    return
  end
  if DamageType.None ~= damageType then
    local skillInfo = args[1]
    local hitEP = args[6]
    if nil == hitEP then
      hitEP = skillInfo:GetHitEP(creature)
    end
    local allowEffect = SkillLogic_Base.AllowTargetEffect(creature, targetCreature)
    local targetPosition, dirAngleY = self:_PlayEffect(creature, targetCreature, damageType, damage, hitEP, allowEffect)
    self:_Hit(creature, targetCreature, damageType, damage, comboDamageLabel, forceSingleDamage, hitEP, targetPosition, allowEffect)
    self:_SpecialHit(creature, targetCreature, damageType, damage, hitEP, targetPosition, dirAngleY, targetIndex, targetCount)
  end
  if nil ~= shareDamageInfos then
    local shareDamageHitEP = RoleDefines_EP.Middle
    local index = 1
    for i = 1, shareDamageInfos[1] do
      self:_DoShareDamage(creature, shareDamageInfos[index + 1], shareDamageInfos[index + 2], shareDamageInfos[index + 3], shareDamageHitEP, damageType, forceSingleDamage)
      index = index + 3
    end
  end
end
function SkillHitWorker:_DoShareDamage(creature, targetGUID, shareDamageType, damage, hitEP, damageType, forceSingleDamage)
  local targetCreature = FindCreature(targetGUID)
  if nil == targetCreature then
    return
  end
  local args = self.args
  local fromPosition = args[2]
  local epTransform = targetCreature.assetRole:GetEPOrRoot(hitEP)
  local targetPosition = tempVector3
  targetPosition:Set(LuaGameObject.GetPosition(epTransform))
  local allowEffect = SkillLogic_Base.AllowTargetEffect(creature, targetCreature)
  self:_Hit(creature, targetCreature, shareDamageType, damage, nil, forceSingleDamage, hitEP, targetPosition, allowEffect)
end
function SkillHitWorker:_PlayEffect(creature, targetCreature, damageType, damage, hitEP, allowEffect)
  if not allowEffect then
    return nil, nil
  end
  local args = self.args
  local skillInfo = args[1]
  local fromPosition = args[2]
  local effectPath = args[5]
  local playDefaultEffect = true
  if DamageType.Block == damageType then
    playDefaultEffect = false
    if nil == effectPath then
      local tempEffectPath, tempHitEP = skillInfo:GetBlockHitEffectInfo(creature, targetCreature)
      if nil ~= tempEffectPath then
        effectPath = tempEffectPath
      end
      if nil ~= tempHitEP then
        hitEP = tempHitEP
      end
    end
  elseif DamageType.AutoBlock == damageType or DamageType.WeaponBlock == damageType then
    playDefaultEffect = false
    effectPath = nil
  elseif DamageType.Treatment == damageType then
    playDefaultEffect = false
    if nil == effectPath then
      effectPath = skillInfo:GetTreatmentHitEffectPath(creature)
      if nil == effectPath then
        effectPath = skillInfo:GetHitEffectPath(creature)
      end
    end
  elseif nil == effectPath and DamageType.Miss ~= damageType and DamageType.Barrier ~= damageType and DamageType.None ~= damageType then
    effectPath = skillInfo:GetHitEffectPath(creature)
  end
  local epTransform = targetCreature.assetRole:GetEPOrRoot(hitEP)
  local targetPosition = tempVector3
  targetPosition:Set(LuaGameObject.GetPosition(epTransform))
  local dirAngleY = VectorHelper.GetAngleByAxisY(fromPosition, targetPosition)
  if nil ~= effectPath then
    local effect = Asset_Effect.PlayOneShotAt(effectPath, targetPosition)
    effect:ResetLocalEulerAnglesXYZ(0, dirAngleY, 0)
  end
  if playDefaultEffect then
    effectPath = skillInfo:GetDefaultHitEffectPath(creature, damageType)
    local effect = Asset_Effect.PlayOneShotAt(effectPath, targetPosition)
    effect:ResetLocalEulerAnglesXYZ(0, dirAngleY, 0)
  end
  return targetPosition, dirAngleY
end
function SkillHitWorker:_Hit(creature, targetCreature, damageType, damage, comboDamageLabel, forceSingleDamage, hitEP, targetPosition, allowEffect)
  local args = self.args
  local skillInfo = args[1]
  local effectTypeName
  if DamageType.AutoBlock == damageType then
    effectTypeName = "AutoBlock"
  elseif DamageType.WeaponBlock == damageType then
    effectTypeName = "WeaponBlock"
  end
  if effectTypeName ~= nil then
    local buffEffect = targetCreature.data:GetBuffEffectByType(effectTypeName)
    if nil ~= buffEffect then
      targetCreature:Logic_Hit(buffEffect.action, buffEffect.stiff)
      local effectEPID = buffEffect.ep or 0
      if nil ~= buffEffect.effect then
        local effectPaths = Game.PreprocessEffectPaths(StringUtil.Split(buffEffect.effect, ","))
        if nil ~= effectPaths then
          local effectPath
          if FunctionPerformanceSetting.Me():GetSetting().effectLow then
            effectPath = effectPaths[2]
          else
            effectPath = effectPaths[1]
          end
          if nil ~= effectPath then
            targetCreature.assetRole:PlayEffectOneShotAt(effectPath, effectEPID)
          end
        end
      end
      if nil ~= buffEffect.se then
        targetCreature.assetRole:PlaySEOneShotAt(buffEffect.se, effectEPID)
      end
    end
    return
  end
  local noHit = skillInfo:NoHit(creature, damageType)
  local damageCount = forceSingleDamage and 1 or skillInfo:GetDamageCount(creature, targetCreature, damageType, damage)
  if not allowEffect then
    if damageCount > 1 then
      local comboArgs = SkillComboHitWorker.GetArgs()
      comboArgs[1] = targetCreature
      comboArgs[2] = damageType
      comboArgs[3] = damage
      comboArgs[4] = damageCount
      comboArgs[5] = hitEP
      comboArgs[6] = noHit
      comboArgs[7] = nil
      comboArgs[8] = nil
      comboArgs[9] = nil
      comboArgs[10] = nil
      comboArgs[11] = creature
      comboArgs[12] = allowEffect
      comboArgs[13] = skillInfo
      Game.SkillWorkerManager:CreateWorker_ComboHit(comboArgs)
      SkillComboHitWorker.ClearArgs(comboArgs)
    end
    return
  end
  if nil == targetPosition then
    return
  end
  local fromPosition = args[2]
  local fromWeaponID = args[4]
  local sePath
  if DamageType.Crit == damageType then
    sePath = AudioMap.Maps.CriticalHit
  else
    sePath = skillInfo:GetHitSEPath(creature, fromWeaponID)
  end
  local labelType, labelColorType = SkillLogic_Base.CalcDamageLabelParams(fromPosition, targetPosition, damageType, targetCreature)
  local labelPosition = targetPosition
  if (DamageType.Miss == damageType or DamageType.Barrier == damageType) and nil ~= creature then
    local missEPTransform = creature.assetRole:GetEPOrRoot(RoleDefines_EP.Middle)
    labelPosition = tempVector3_1
    labelPosition:Set(LuaGameObject.GetPosition(missEPTransform))
  end
  if damageCount > 1 then
    local comboArgs = SkillComboHitWorker.GetArgs()
    comboArgs[1] = targetCreature
    comboArgs[2] = damageType
    comboArgs[3] = damage
    comboArgs[4] = damageCount
    comboArgs[5] = hitEP
    comboArgs[6] = noHit
    comboArgs[7] = sePath
    comboArgs[8] = labelType
    comboArgs[9] = labelColorType
    comboArgs[10] = comboDamageLabel
    comboArgs[11] = creature
    comboArgs[12] = allowEffect
    comboArgs[13] = skillInfo
    Game.SkillWorkerManager:CreateWorker_ComboHit(comboArgs)
    SkillComboHitWorker.ClearArgs(comboArgs)
  else
    if not noHit then
      targetCreature:Logic_Hit()
    end
    SkillLogic_Base.ShowDamage_Single(damageType, damage, labelPosition, labelType, labelColorType, targetCreature, skillInfo)
    if nil ~= comboDamageLabel then
      local comboEPTransform = targetCreature.assetRole:GetEPOrRoot(RoleDefines_EP.Top)
      labelPosition:Set(LuaGameObject.GetPosition(comboEPTransform))
      comboDamageLabel:Show(damage, labelPosition)
    end
    if nil ~= sePath then
      targetCreature.assetRole:PlaySEOneShotAt(sePath, hitEP)
    end
  end
end
function SkillHitWorker:_SpecialHit(creature, targetCreature, damageType, damage, hitEP, targetPosition, dirAngleY, targetIndex, targetCount)
  local args = self.args
  local skillInfo = args[1]
  local specialEffects = skillInfo:GetSpecialHitEffects(creature)
  if nil == specialEffects or #specialEffects <= 0 then
    return
  end
  local fromPosition = args[2]
  local targetCreatureLogicTransform = targetCreature.logicTransform
  local pvpMap = Game.MapManager:IsPVPMode()
  local isGVG = Game.MapManager:IsPVPMode_GVGDetailed()
  for i = 1, #specialEffects do
    local specialEffect = specialEffects[i]
    if (not pvpMap or 1 ~= specialEffect.no_pvp) and SpecialHitEffectTypes.HitEffectMove == specialEffect.type and not skillInfo:NoHitEffectMove(targetCreature, damageType, damage) and (1 ~= targetIndex or not skillInfo:NoRepelMajor(creature)) and (not isGVG or "back" ~= specialEffect.direction) then
      if nil == targetPosition then
        local epTransform = targetCreature.assetRole:GetEPOrRoot(hitEP)
        targetPosition = tempVector3
        targetPosition:Set(LuaGameObject.GetPosition(epTransform))
      end
      if nil == dirAngleY then
        dirAngleY = VectorHelper.GetAngleByAxisY(fromPosition, targetPosition)
      end
      local dirMoveAngleY, dirMoveDistance
      if "back" == specialEffect.direction then
        dirMoveAngleY = dirAngleY
        dirMoveDistance = specialEffect.distance
      elseif "forward" == specialEffect.direction then
        dirMoveAngleY = NumberUtility.Repeat(dirAngleY + 180, 360)
        if nil ~= creature then
          dirMoveDistance = math.min(specialEffect.distance, VectorUtility.DistanceXZ(creature:GetPosition(), targetPosition))
        else
          dirMoveDistance = math.min(specialEffect.distance, VectorUtility.DistanceXZ(fromPosition, targetPosition))
        end
      end
      targetCreatureLogicTransform:ExtraDirMove(dirMoveAngleY, dirMoveDistance, specialEffect.speed)
    end
  end
end
function SkillHitWorker:_MultiSpecialHit(targets)
  local skillInfo = self.args[1]
  local specialEffects = skillInfo:GetSpecialHitEffects(creature)
  if specialEffects == nil or #specialEffects <= 0 then
    return
  end
  local effectLow = FunctionPerformanceSetting.Me():GetSetting().effectLow
  for i = 1, #specialEffects do
    local specialEffect = specialEffects[i]
    if specialEffect.type == SpecialHitEffectTypes.MultiTargetConnect then
      if effectLow then
        return
      end
      for j = 1, #targets do
        local creature = FindCreature(targets[j])
        if creature ~= nil then
          local nextTarget = targets[j + 1]
          if nextTarget == nil then
            nextTarget = targets[1]
          end
          creature:Client_AddSpEffect(nextTarget, specialEffect.speffect, specialEffect.duration)
        end
      end
    end
  end
end
function SkillHitWorker:Delay()
  if self.delayed then
    return
  end
  self.delayed = true
  local args = self.args
  local targetCount = args[7]
  if targetCount > 0 then
    for i = 1, targetCount do
      local index = 7 + (i - 1) * 5
      local targetCreature = FindCreature(args[index + 1])
      if nil ~= targetCreature then
        targetCreature.ai:SetDieBlocker(self)
      end
      local comboDamageLabel = args[index + 5]
      if nil ~= comboDamageLabel then
        comboDamageLabel:AddRef()
      end
    end
  end
end
function SkillHitWorker:DoConstruct(asArray, args)
  self.ref = 0
  self.delayed = false
end
function SkillHitWorker:DoDeconstruct(asArray)
  local args = self.args
  local targetCount = args[7]
  if targetCount > 0 then
    if self.delayed then
      for i = 1, targetCount do
        local index = 7 + (i - 1) * 5
        local targetCreature = FindCreature(args[index + 1])
        if nil ~= targetCreature then
          targetCreature.ai:ClearDieBlocker(self)
        end
        DestroyShareDamageInfos(args[index + 4])
        args[index + 4] = nil
        local comboDamageLabel = args[index + 5]
        if nil ~= comboDamageLabel then
          comboDamageLabel:SubRef()
          args[index + 5] = nil
        end
      end
    else
      for i = 1, targetCount do
        local index = 7 + (i - 1) * 5
        DestroyShareDamageInfos(args[index + 4])
        args[index + 4] = nil
        local comboDamageLabel = args[index + 5]
        if nil ~= comboDamageLabel then
          args[index + 5] = nil
        end
      end
    end
  end
  args[7] = 0
end
