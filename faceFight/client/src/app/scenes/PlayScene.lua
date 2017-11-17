
local PlayScene = class("PlayScene", function()
    return display.newScene("PlayScene")
end)

local random = math.random

function PlayScene:ctor()
    local bg = display.newSprite("common_bg.jpg", display.cx, display.cy)
    local scaleX = display.width / bg:getContentSize().width
    local scaleY = display.height / bg:getContentSize().height
    bg:setScaleX(scaleX)
    bg:setScaleY(scaleY)
    self:addChild(bg, -1)
    
    self.layer = display.newNode()
    self.layer:setContentSize(cc.size(display.width, display.height))
    self:addChild(self.layer)

    cc.ui.UIPushButton.new({normal = "toggle_104_normal.png", pressed = "toggle_104_select.png"})
        :onButtonClicked(function ()
        	app:closeConnect()
            app:enterScene("MainScene")
        end)
        :pos(display.right - 90, 50)
        :setButtonLabel("normal", display.newTTFLabel({text = "返回主菜单", size = 20, font = "", color = cc.c3b(0xff, 0xff, 0x00)}))
        :addTo(self)

    self.player_list = {}

    self.update_obj_list = {}
    self:addNodeEventListener(cc.NODE_ENTER_FRAME_EVENT, function(...)
            self:update_(...)
        end)
    self:scheduleUpdate()
end

function PlayScene:onEnter()
    self.layer:setKeypadEnabled(true)
    self.layer:addNodeEventListener(cc.KEYPAD_EVENT, function (event)
        -- local str = "event.key is [ " .. event.key .. " ]"
        self:doKeyMove(event)
    end)

    self:createPlayer(app.player_data)
    for k, v in pairs(app.player_data_list) do
        self:createPlayer(v)
    end

    self.sc_player_move_h = app:addEventListener("sc_player_move", handler(self, self.onObjMove))
    self.sc_world_vis_player_h = app:addEventListener("sc_world_vis_player", handler(self, self.onObjCreate))
    self.sc_one_player_close_h = app:addEventListener("cs_one_player_close", handler(self, self.onObjRemove))
end

function PlayScene:removePlayer(t)
    if nil == self.player_list[t.playerId] then
        return
    end
    self.player_list[t.playerId]:outScene()
    self.player_list[t.playerId] = nil
end

function PlayScene:createPlayer(t)
    -- dump(t)
    if nil ~= self.player_list[t.playerId] then
        return
    end

    local player = {}
    local show_node = display.newSprite("player1.png"):pos(t.pos.x, t.pos.y):addTo(self)
    cc.ui.UILabel.new({
            UILabelType = 2, text = t.name, size = 25, color = cc.c3b(0xff, 0x28, 0x28)})
        :pos(0, 39)
        :addTo(show_node)

    player.show_node = show_node
    player.data = t
    player.outScene = function(self)
        self.show_node:removeSelf()
    end

    self.player_list[t.playerId] = player

    return player
end

function PlayScene:onObjMove(data)
    local param = data.param
    if param then
        local player = self:getObjById(param.playerId)
        if player then
            -- dump(param)
            player.show_node:setPosition(param.pos)
        end
    end
end

function PlayScene:getObjById(id)
   return self.player_list[id]
end

function PlayScene:onObjRemove(data)
    -- dump(data)
    self:removePlayer(data.param)
end

local NO_IDR = -1
local update_move_time = NOW_TIME
local cache_move_key_list = {}
local dir_offset = {
    [cc.KeyCode.KEY_W] = cc.p(0, 1),
    [cc.KeyCode.KEY_S] = cc.p(0, -1),
    [cc.KeyCode.KEY_A] = cc.p(-1, 0),
    [cc.KeyCode.KEY_D] = cc.p(1, 0),
}
function PlayScene:updateMainRoleMove(dt)
    local move_pos = cc.p(0, 0)
    for i = 1, 2 do
        local move_offset = dir_offset[cache_move_key_list[i]]
        if move_offset then
            move_pos.x = move_pos.x + move_offset.x
            move_pos.y = move_pos.y + move_offset.y
        end
    end

    if move_pos.x ~= 0 or move_pos.y ~= 0 then
        local speed = 100 -- (xp/秒)
        local move_jl = speed * dt
        if move_pos.x ~= 0 and move_pos.y ~= 0 then
            local xie_jl = math.sqrt(move_jl * move_jl / 2)
            move_pos.x = xie_jl * move_pos.x
            move_pos.y = xie_jl * move_pos.y
        elseif move_pos.x ~= 0 then
            move_pos.x = move_jl * move_pos.x
        elseif move_pos.y ~= 0 then
            move_pos.y = move_jl * move_pos.y
        end
        app:sendData({cmd = "cs_player_move", param = {movePos = move_pos}})
    end
end

function PlayScene:doKeyMove(event)
    local move_dir_p = dir_offset[event.code]
    if move_dir_p then
        if "Pressed" == event.type then  -- 按下
            table.insert(cache_move_key_list, 1, event.code)
        else                -- 松开
            for k, v in pairs(cache_move_key_list) do
                if event.code == v then
                    table.remove(cache_move_key_list, k)
                    break
                end
            end
        end
    end
end

function PlayScene:onObjCreate(data)
    local param = data.param
    if param then
        self:createPlayer(param)
    end
end

function PlayScene:update_(dt)
    self:updateMainRoleMove(dt)
end

function PlayScene:onExit()
    app:removeEventListener(self.sc_player_move_h)
    app:removeEventListener(self.sc_world_vis_player_h)
    app:removeEventListener(self.sc_one_player_close_h)
end

return PlayScene
