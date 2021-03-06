autoImport("ServiceChatCmdAutoProxy")
ServiceChatCmdProxy = class("ServiceChatCmdProxy", ServiceChatCmdAutoProxy)
ServiceChatCmdProxy.Instance = nil
ServiceChatCmdProxy.NAME = "ServiceChatCmdProxy"
function ServiceChatCmdProxy:ctor(proxyName)
  if ServiceChatCmdProxy.Instance == nil then
    self.proxyName = proxyName or ServiceChatCmdProxy.NAME
    ServiceProxy.ctor(self, self.proxyName)
    self:Init()
    ServiceChatCmdProxy.Instance = self
  end
end
function ServiceChatCmdProxy:RecvPlayExpressionChatCmd(data)
  LogUtility.InfoFormat("RecvPlayExpressionChatCmd : charid : {0} , expressionid : {1}", data.charid, data.expressionid)
  FunctionPlayerHead.Me():PlayEmoji(data)
end
function ServiceChatCmdProxy:RecvQueryUserInfoChatCmd(data)
  if data.type == ChatCmd_pb.EUSERINFOTYPE_CHAT then
    local msgId = data and data.msgid
    if msgId ~= 0 then
      MsgManager.ShowMsgByIDTable(msgId)
    else
      local dataInfo = data and data.info
      if dataInfo then
        GameFacade.Instance:sendNotification(UIEvent.JumpPanel, {
          view = PanelConfig.PlayerDetailView,
          viewdata = {dataInfo = dataInfo}
        })
      end
    end
  end
  self:Notify(ServiceEvent.ChatCmdQueryUserInfoChatCmd, data)
end
function ServiceChatCmdProxy:CallChatCmd(channel, str, desID, voice, voicetime, msgid, msgover)
  if channel == ChatChannelEnum.World and MyselfProxy.Instance:RoleLevel() < GameConfig.System.chat_world_reqlv then
    MsgManager.ShowMsgByID(77)
    return
  end
  local _ChatRoomProxy = ChatRoomProxy.Instance
  if _ChatRoomProxy:CheckSoliloquize(channel, str, desID) then
    return
  end
  str = _ChatRoomProxy:StripSymbols(str)
  str = _ChatRoomProxy:TryParseItemCodeToItemData(str)
  str = _ChatRoomProxy:TryParseTutorContentToCode(str)
  if voice then
    msgid = ChatRoomProxy.Instance:GetVoiceId()
    if msgid ~= nil then
      local byteArray = ByteArray(voice, 20000)
      local splitLength = byteArray:GetSplitLength()
      LogUtility.InfoFormat("CallChatCmd : voice : {0} , splitLength : {1}", tostring(#voice), tostring(splitLength))
      for i = 1, splitLength do
        local splitByte = byteArray:GetSplitArrayByIndex(i - 1)
        local splitByteStr = Slua.ToString(splitByte)
        local isOver = false
        if i == splitLength then
          isOver = true
          ServiceChatCmdProxy.super.CallChatCmd(self, channel, str, desID, splitByteStr, voicetime, msgid, isOver)
          ServiceChatCmdProxy.Instance:CallGetVoiceIDChatCmd()
        else
          ServiceChatCmdProxy.super.CallChatCmd(self, nil, "", nil, splitByteStr, nil, msgid, isOver)
        end
      end
    end
  else
    ServiceChatCmdProxy.super.CallChatCmd(self, channel, str, desID, voice, voicetime, msgid, msgover)
  end
end
function ServiceChatCmdProxy:RecvChatRetCmd(data)
  if data.voiceid ~= nil and data.voicetime ~= 0 and ApplicationInfo.NeedOpenVoiceSend() == false then
    return
  end
  for i = 1, #GameConfig.ChatRoom.BlackList do
    if data.channel == GameConfig.ChatRoom.BlackList[i] and not TeamProxy.Instance:IsInMyTeam(data.id) and FriendProxy.Instance:IsBlacklist(data.id) then
      return
    end
  end
  local chat = ChatRoomProxy.Instance:RecvChatMessage(data)
  self:Notify(ServiceEvent.ChatCmdChatRetCmd, chat)
end
function ServiceChatCmdProxy:RecvQueryVoiceUserCmd(data)
  helplog("RecvQueryVoiceUserCmd")
  if self.queryVoice == nil then
    self.queryVoice = {}
  end
  if self.queryVoice[data.msgid] == nil then
    self.queryVoice[data.msgid] = ByteArray()
  end
  self.queryVoice[data.msgid]:AddMergeByte(Slua.ToBytes(data.voice))
  if data.msgover then
    helplog("RecvQueryVoiceUserCmd data.msgover")
    local newData = {}
    newData.voiceid = data.voiceid
    newData.voice = Slua.ToString(self.queryVoice[data.msgid]:MergeByte())
    newData.path = ChatRoomProxy.Instance:RecvChatSpeech(newData)
    self:Notify(ServiceEvent.ChatCmdQueryVoiceUserCmd, newData)
    self.queryVoice[data.msgid] = nil
  end
end
function ServiceChatCmdProxy:RecvBarrageMsgChatCmd(data)
  self:Notify(ServiceEvent.ChatCmdBarrageMsgChatCmd, data)
  EventManager.Me():PassEvent(ServiceEvent.ChatCmdBarrageMsgChatCmd, data)
end
function ServiceChatCmdProxy:CallQueryItemData(guid, data)
  local msg = ChatCmd_pb.QueryItemData()
  if guid ~= nil then
    msg.guid = guid
  end
  self:SendProto(msg)
end
function ServiceChatCmdProxy:CallGetVoiceIDChatCmd(id)
  ChatRoomProxy.Instance:ResetVoiceId()
  ServiceChatCmdProxy.super.CallGetVoiceIDChatCmd(self, id)
end
function ServiceChatCmdProxy:RecvGetVoiceIDChatCmd(data)
  ChatRoomProxy.Instance:RecvGetVoiceIDChatCmd(data.id)
  self:Notify(ServiceEvent.ChatCmdGetVoiceIDChatCmd, data)
end
function ServiceChatCmdProxy:RecvLoveLetterNtf(data)
  StarProxy.Instance:RecvLoveLetterNtf(data)
  self:Notify(ServiceEvent.ChatCmdLoveLetterNtf, data)
end
function ServiceChatCmdProxy:RecvNpcChatNtf(data)
  ChatRoomProxy.Instance:RecvNpcChatNtf(data)
  self:Notify(ServiceEvent.ChatCmdNpcChatNtf, data)
end
function ServiceChatCmdProxy:RecvQueryRealtimeVoiceIDCmd(data)
  GVoiceProxy.Instance:RecvQueryRealtimeVoiceIDCmd(data)
  self:Notify(ServiceEvent.ChatCmdQueryRealtimeVoiceIDCmd, data)
end
function ServiceChatCmdProxy:RecvSystemBarrageChatCmd(data)
  BarrageProxy.Instance:RecvSystemBarrageChatCmd(data)
  self:Notify(ServiceEvent.ChatCmdSystemBarrageChatCmd, data)
end
