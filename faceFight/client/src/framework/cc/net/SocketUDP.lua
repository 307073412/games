--[[
For quick-cocos2d-x
SocketUDP lua
@author zrong (zengrong.net)
Creation: 2013-11-12
Last Modification: 2013-12-05
@see http://cn.quick-x.com/?topic=quickkydsocketfzl

2016.6.28 merget Yue's change, add ipv6 support
]]
local SOCKET_RECONNECT_TIME = 5			-- socket reconnect try interval
local SOCKET_CONNECT_FAIL_TIMEOUT = 3	-- socket failure timeout

local STATUS_CLOSED = "closed"
local STATUS_NOT_CONNECTED = "Socket is not connected"
local STATUS_ALREADY_CONNECTED = "already connected"
local STATUS_ALREADY_IN_PROGRESS = "Operation already in progress"
local STATUS_TIMEOUT = "timeout"

local scheduler = require("framework.scheduler")
local socket = require "socket"

local SocketUDP = class("SocketUDP")

SocketUDP.EVENT_DATA = "SOCKET_TCP_DATA"
SocketUDP.EVENT_CLOSE = "SOCKET_TCP_CLOSE"
SocketUDP.EVENT_CLOSED = "SOCKET_TCP_CLOSED"
SocketUDP.EVENT_CONNECTED = "SOCKET_TCP_CONNECTED"
SocketUDP.EVENT_CONNECT_FAILURE = "SOCKET_TCP_CONNECT_FAILURE"

SocketUDP._VERSION = socket._VERSION
SocketUDP._DEBUG = socket._DEBUG

function SocketUDP.getTime()
	return socket.gettime()
end

function SocketUDP:ctor(__host, __port, __retryConnectWhenFailure)
	cc(self):addComponent("components.behavior.EventProtocol"):exportMethods()

    self.host = __host
    self.port = __port
	self.tickScheduler = nil			-- timer for data
	self.reconnectScheduler = nil		-- timer for reconnect
	self.connectTimeTickScheduler = nil	-- timer for connect timeout
	self.name = 'SocketUDP'
	self.udp = nil
	self.isRetryConnect = __retryConnectWhenFailure
	self.isConnected = false
end

function SocketUDP:setName( __name )
	self.name = __name
	return self
end


function SocketUDP:setReconnTime(__time)
	SOCKET_RECONNECT_TIME = __time
	return self
end

function SocketUDP:setConnFailTime(__time)
	SOCKET_CONNECT_FAIL_TIMEOUT = __time
	return self
end

function SocketUDP:connect(__host, __port, __retryConnectWhenFailure)
	if __host then self.host = __host end
	if __port then self.port = __port end
	if __retryConnectWhenFailure ~= nil then self.isRetryConnect = __retryConnectWhenFailure end
	assert(self.host or self.port, "Host and port are necessary!")
	-- printInfo("%s.connect(%s, %d)", self.name, self.host, self.port)
	self.udp = socket.udp()
	self.udp:settimeout(0)
	self.udp:setpeername(self.host, self.port)

	if not self:_checkConnect() then
	-- 	-- remove the old tcp scheduler
	-- 	if self.connectTimeTickScheduler then scheduler.unscheduleGlobal(self.connectTimeTickScheduler) end
	-- 	self.connectTimeTickScheduler = scheduler.scheduleUpdateGlobal(handler(self, self._connectTimeTick))
	end
end

function SocketUDP:send(__data)
	-- assert(self.isConnected, self.name .. " is not connected.")
	self.udp:send(__data)
end

function SocketUDP:close( ... )
	--printInfo("%s.close", self.name)
	self.udp:close();
	-- if self.connectTimeTickScheduler then scheduler.unscheduleGlobal(self.connectTimeTickScheduler) end
	if self.tickScheduler then scheduler.unscheduleGlobal(self.tickScheduler) end
	self:dispatchEvent({name=SocketUDP.EVENT_CLOSE})
end

-- disconnect on user's own initiative.
function SocketUDP:disconnect()
	self:_disconnect()
	self.isRetryConnect = false -- initiative to disconnect, no reconnect.
end

--------------------
-- private
--------------------

function SocketUDP:_checkConnect()
	local __succ = self:_connect()
	if __succ then
		self:_onConnected()
	end
	return __succ
end

function SocketUDP:_connectTimeTick(dt)
	if self.isConnected then return end
	self.waitConnect = self.waitConnect or 0
	self.waitConnect = self.waitConnect + dt
	if self.waitConnect >= SOCKET_CONNECT_FAIL_TIMEOUT then
		self.waitConnect = nil
		self:close()
		self:_connectFailure()
	end
	self:_checkConnect()
end
function SocketUDP:_tick(dt)
	local __body, __status, __partial = self.udp:receive(1024)	-- read the package body
	-- print("body:", __body, "__status:", __status, "__partial:", __partial)
    if __status == STATUS_CLOSED or __status == STATUS_NOT_CONNECTED then
    	self:close()
    	if self.isConnected then
    		self:_onDisconnect()
    	else
    		self:_connectFailure()
    	end
   		return
	end
    if 	(__body and string.len(__body) == 0) or
		(__partial and string.len(__partial) == 0)
	then return end
	if __body and __partial then __body = __body .. __partial end
	self:dispatchEvent({name=SocketUDP.EVENT_DATA, data=(__partial or __body), partial=__partial, body=__body})
end
--- When connect a connected socket server, it will return "already connected"
-- @see: http://lua-users.org/lists/lua-l/2009-10/msg00584.html
function SocketUDP:_connect()
	-- local __succ, __status = self.udp:connect(self.host, self.port)
	-- -- print("SocketUDP._connect:", __succ, __status)
	-- return __succ == 1 or __status == STATUS_ALREADY_CONNECTED
	return true
end

function SocketUDP:_disconnect()
	self.isConnected = false
	-- self.udp:shutdown()
	self:dispatchEvent({name=SocketUDP.EVENT_CLOSED})
end

function SocketUDP:_onDisconnect()
	-- print("%s._onDisConnect", self.name);
	self.isConnected = false
	self:dispatchEvent({name=SocketUDP.EVENT_CLOSED})
	self:_reconnect();
end

-- connecte success, cancel the connection timerout timer
function SocketUDP:_onConnected()
	-- print("%s._onConnectd", self.name)
	self.isConnected = true
	self:dispatchEvent({name=SocketUDP.EVENT_CONNECTED})
	if self.connectTimeTickScheduler then scheduler.unscheduleGlobal(self.connectTimeTickScheduler) end	
	-- start to read TCP data
	self.tickScheduler = scheduler.scheduleUpdateGlobal(handler(self, self._tick))
end

function SocketUDP:_connectFailure(status)
	-- print("%s._connectFailure", self.name);
	self:dispatchEvent({name=SocketUDP.EVENT_CONNECT_FAILURE})
	self:_reconnect();
end

-- if connection is initiative, do not reconnect
function SocketUDP:_reconnect(__immediately)
	if not self.isRetryConnect then return end
	-- print("%s._reconnect", self.name)
	if __immediately then self:connect() return end
	if self.reconnectScheduler then scheduler.unscheduleGlobal(self.reconnectScheduler) end
	local __doReConnect = function ()
		self:connect()
	end
	self.reconnectScheduler = scheduler.performWithDelayGlobal(__doReConnect, SOCKET_RECONNECT_TIME)
end

return SocketUDP
