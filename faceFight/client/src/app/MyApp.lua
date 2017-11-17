
require("config")
require("cocos.init")
require("framework.init")

local net = require("framework.cc.net.init")
local json = json

local MyApp = class("MyApp", cc.mvc.AppBase)

MyApp.EVENT_DATA = "SOCKET_TCP_DATA"
MyApp.EVENT_CLOSE = "SOCKET_TCP_CLOSE"
MyApp.EVENT_CLOSED = "SOCKET_TCP_CLOSED"
MyApp.EVENT_CONNECTED = "SOCKET_TCP_CONNECTED"
MyApp.EVENT_CONNECT_FAILURE = "SOCKET_TCP_CONNECT_FAILURE"

function MyApp:ctor()
    MyApp.super.ctor(self)

    self:initGameNet()

    self.player_data = nil
    self.player_data_list = {}
end

function MyApp:run()
    cc.FileUtils:getInstance():addSearchPath("res/")
    cc.FileUtils:getInstance():addSearchPath("../csShare/")

	self.csDefine = loadJsonFile("csDefine.js")
    self:enterScene("MainScene")

    self:addEventListener("sc_world_vis_player", handler(self, self.onObjCreate))
    self:addEventListener("one_player_close", handler(self, self.onObjRemove))
end

function MyApp:onObjRemove(data)
	if data.param then
	    self.player_data_list[data.param.playerId] = nil
	end
end

function MyApp:onObjCreate(data)
	local param = data.param
    if param then
        self.player_data_list[param.playerId] = param
    end
end

function MyApp:initGameNet()
    local time = net.SocketUDP.getTime()
	print("socket time:" .. time)

	local socket = net.SocketUDP.new()
	socket:setName("game")
	socket:setReconnTime(6)
	socket:setConnFailTime(4)

	socket:addEventListener(net.SocketUDP.EVENT_DATA, handler(self, self.tcpData))
	socket:addEventListener(net.SocketUDP.EVENT_CLOSE, handler(self, self.tcpClose))
	socket:addEventListener(net.SocketUDP.EVENT_CLOSED, handler(self, self.tcpClosed))
	socket:addEventListener(net.SocketUDP.EVENT_CONNECTED, handler(self, self.tcpConnected))
	socket:addEventListener(net.SocketUDP.EVENT_CONNECT_FAILURE, handler(self, self.tcpConnectedFail))

	self.socket_ = socket
end

function MyApp:tcpData(event)
	if nil == event.data then
		return
	end

	print("SocketUDP receive data:" .. event.data)
	local event_data = string.split(event.data, self.csDefine.procotolTailMark)
	for k, v in pairs(event_data) do
		local data = json.decode(v)
		-- print("XWH--->>>data.cmd", v, data and data.cmd)
		if data and data.cmd then
			self:dispatchEvent({name = data.cmd, param = data.param})
		end
	end
end

function MyApp:connectServer()
	if not self.socket_.isConnected then
		self:dispatchEvent({name = "server_state_change", server_state = "connecting"})
		self.socket_:connect(self.csDefine.HOST, self.csDefine.PORT, true)
	end
end

function MyApp:tcpClose()
	print("SocketUDP close")
	self:dispatchEvent({name = "server_state_change", server_state = "close"})
end

function MyApp:tcpClosed()
	print("SocketUDP closed")
end

function MyApp:tcpConnected()
	self:dispatchEvent({name = "server_state_change", server_state = "connected"})
end

function MyApp:tcpConnectedFail()
	self:dispatchEvent({name = "server_state_change", server_state = "fail"})
end

function MyApp:isConnected()
	return self.socket_.isConnected
end

function MyApp:sendData(data)
	if self.socket_.isConnected and data then
		local data = json.encode(data) .. self.csDefine.procotolTailMark
		print("XWH--->>>setdata", data)
		self.socket_:send(data)
	end
end

function MyApp:closeConnect()
	if self.socket_.isConnected then
		self.socket_:close()
	end
	self.socket_:disconnect()
end

function MyApp:createPlayer(param)
	self:sendData({cmd = 'cs_create_player', param = param})
end

function MyApp:exit()
	MyApp.super.exit(self)

	self:closeConnect()
end

return MyApp
