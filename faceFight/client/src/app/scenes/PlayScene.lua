
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

    self.cor_wait_time = 0
    self.cor_pass_time = 0
    cc.ui.UIPushButton.new({normal = "toggle_104_normal.png", pressed = "toggle_104_select.png"})
        :onButtonClicked(function ()
        	-- app:closeConnect()
            -- app:enterScene("MainScene")

            if self.cor == nil then
                self.cor = coroutine.create(self.ShortestPath_Dijkstra)
                _, self.cor_wait_time = coroutine.resume(self.cor, self, self.Graph, 2)
                print("XWH--->>>self.cor_wait_time", self.cor_wait_time)
                self.cor_pass_time = 0
            else
                local ok, ret = coroutine.resume(self.cor)
                if not ok then
                    self.cor = nil
                end
                print("XWH--->>>coroutine.resume", ret)
            end
        end)
        :pos(display.right - 90, 50)
        :setButtonLabel("normal", display.newTTFLabel({text = "继续", size = 20, font = "", color = cc.c3b(0xff, 0xff, 0x00)}))
        :addTo(self)

    self.player_list = {}

    self.update_obj_list = {}
    self:addNodeEventListener(cc.NODE_ENTER_FRAME_EVENT, function(...)
            self:update_(...)
        end)
    self:scheduleUpdate()

    self.cor = nil
    self:CreateShortestPathDijkstraView()
end

PlayScene.INFINITY = 65535
function PlayScene:CreateShortestPathDijkstraView()
    local M = PlayScene.INFINITY
    local bit_w = 120
    local bit_w_2 = bit_w / 2
    local bit_w_3 = bit_w * math.cos(math.angle2radian(30))
    self.Graph = {
        numVertexes = 9,
        numEdges = 14,
        arc = {
            [0] = {[0]=0, [1]=1, [2]=5, [3]=M, [4]=M, [5]=M, [6]=M, [7]=M, [8]=M},
            [1] = {[0]=1, [1]=0, [2]=3, [3]=7, [4]=5, [5]=M, [6]=M, [7]=M, [8]=M},
            [2] = {[0]=5, [1]=3, [2]=0, [3]=M, [4]=1, [5]=7, [6]=M, [7]=M, [8]=M},
            [3] = {[0]=M, [1]=7, [2]=M, [3]=0, [4]=2, [5]=M, [6]=3, [7]=M, [8]=M},
            [4] = {[0]=M, [1]=5, [2]=1, [3]=2, [4]=0, [5]=3, [6]=6, [7]=9, [8]=M},
            [5] = {[0]=M, [1]=M, [2]=7, [3]=M, [4]=3, [5]=0, [6]=M, [7]=5, [8]=M},
            [6] = {[0]=M, [1]=M, [2]=M, [3]=3, [4]=6, [5]=M, [6]=0, [7]=2, [8]=7},
            [7] = {[0]=M, [1]=M, [2]=M, [3]=M, [4]=9, [5]=5, [6]=2, [7]=0, [8]=4},
            [8] = {[0]=M, [1]=M, [2]=M, [3]=M, [4]=M, [5]=M, [6]=7, [7]=4, [8]=0},
        },
        pos_t = {
            [0] = cc.p(0, 0),
            [1] = cc.p(bit_w_3, bit_w_2),
            [2] = cc.p(bit_w_3, -bit_w_2),
            [3] = cc.p(2 * bit_w_3, bit_w),
            [4] = cc.p(2 * bit_w_3, 0),
            [5] = cc.p(2 * bit_w_3, -bit_w),
            [6] = cc.p(3 * bit_w_3, bit_w_2),
            [7] = cc.p(3 * bit_w_3, -bit_w_2),
            [8] = cc.p(4 * bit_w_3, 0),
        },
        v_node_t = {},
        e_node_t = {},
    }

    self.g_layer = display.newNode()
    self.g_layer:setContentSize(cc.size(display.width, display.height))
    self.g_layer:setPosition(100, 200)
    self:addChild(self.g_layer, 10)

    local area_angle = {
        [1] = {[1] = 1, [-1] = 4},
        [-1] = {[1] = 2, [-1] = 3},
    }
    local function get_rota(p1, p2)
        local angle = 0
        local xc = p2.x - p1.x
        local yc = p2.y - p1.y
        local abs_xc = math.abs(xc)
        local abs_yc = math.abs(yc)

        local a = math.atan(abs_yc / abs_xc)
        local i1 = xc == 0 and 1 or (xc / abs_xc)
        local i2 = yc == 0 and 1 or (yc / abs_yc)
        local area_idx = area_angle[i1][i2]
        if area_idx == 1 then
            a = a
        elseif area_idx == 2 then
            a = 1 * math.pi - a
        elseif area_idx == 3 then
            a = 1 * math.pi + a
        elseif area_idx == 4 then
            a = 2 * math.pi - a
        end
        return math.radian2angle(a)
    end

    for k, v in pairs(self.Graph.pos_t) do
        local name = "v" .. k
        local show_node = display.newSprite("player1.png"):pos(v.x, v.y):addTo(self.g_layer, 1)
        cc.ui.UILabel.new({UILabelType = 2, text = name, size = 20, color = cc.c3b(0xff, 0x28, 0x28)})
            :pos(0, 0)
            :addTo(show_node)
        self.Graph.v_node_t[k] = {show_node = show_node, p = v, name = name, index = k}

        -- if k == 1 then
            for v2, v_weight in pairs(self.Graph.arc[k]) do
                if v_weight > 0 and v_weight ~= M and (self.Graph.e_node_t[k] == nil or self.Graph.e_node_t[k][v2] == nil) then
                    local show_node = display.newSprite("line1.png"):addTo(self.g_layer, 0)
                    display.align(show_node, display.CENTER_LEFT, v.x, v.y)
                    v2_p = self.Graph.pos_t[v2]
                    local ro = get_rota(v, v2_p)
                    show_node:setRotation(-ro)
                    show_node:setScaleX(cc.pGetDistance(v, v2_p) / show_node:getContentSize().width)

                    cc.ui.UILabel.new({UILabelType = 2, text = v_weight, size = 20, color = cc.c3b(0x1e, 0xff, 0x00)})
                        :pos(show_node:getContentSize().width / 2, 2)
                        :addTo(show_node)

                    if self.Graph.e_node_t[k] == nil then
                        self.Graph.e_node_t[k] = {}
                    end
                    if self.Graph.e_node_t[v2] == nil then
                        self.Graph.e_node_t[v2] = {}
                    end
                    self.Graph.e_node_t[k][v2] = {show_node = show_node, ro = ro, weight = v_weight}
                    self.Graph.e_node_t[v2][k] = self.Graph.e_node_t[k][v2]
                end 
            end
        -- end
    end
end

function PlayScene:ShortestPath_Dijkstra(G, tag_v)
    local yreturn
    yreturn = coroutine.yield(1)

    local pathmatirx = {}
    local shortPathTable = {}
    local v, w, k, min
    local final = {}
    for i = 0, G.numVertexes - 1 do
        final[i] = 0
        pathmatirx[i] = tag_v
        shortPathTable[i] = G.arc[tag_v][i]
    end

    shortPathTable[tag_v] = 0
    final[tag_v] = 1

    G.v_node_t[tag_v].show_node:setColor(cc.c3b(0x1e, 0xff, 0x00))
    yreturn = coroutine.yield(1)

    local t = {}
    for i = 0, G.numVertexes - 1 do
        min = PlayScene.INFINITY
        for w = 0, G.numVertexes - 1 do
            if 0 == final[w] then

                if shortPathTable[w] < min then
                    min = shortPathTable[w]
                    k = w
                end
            end
        end

        for _, node in pairs(t) do
            node:setColor(cc.c3b(0xff, 0xff, 0xff))
        end

        -- 确定一个顶点的最短路径
        final[k] = 1

        local t = {}
        local tag_w = k
        while tag_w ~= tag_v do
            local p_w = pathmatirx[tag_w]
            local node = G.e_node_t[p_w][tag_w].show_node
            t[#t + 1] = node
            node:setColor(cc.c3b(0x1e, 0xff, 0x00))
            tag_w = p_w
        end
        yreturn = coroutine.yield(1)
        G.v_node_t[k].show_node:setColor(cc.c3b(0x1e, 0xff, 0x00))
        yreturn = coroutine.yield(1)

        for w = 0, G.numVertexes - 1 do
            if 0 == final[w] and (min + G.arc[k][w]) < shortPathTable[w] then
                shortPathTable[w] = min + G.arc[k][w]
                pathmatirx[w] = k

                local node = G.e_node_t[k][w].show_node
                t[#t + 1] = node
                node:setColor(cc.c3b(0x00, 0x00, 0xff))

                yreturn = coroutine.yield(1)
            end
        end

        for _, node in pairs(t) do
            node:setColor(cc.c3b(0xff, 0xff, 0xff))
        end
        yreturn = coroutine.yield(1)
    end

    dump(shortPathTable)
    yreturn = coroutine.yield(1)
    for k, v in pairs(G.v_node_t) do
        v.show_node:setColor(display.COLOR_WHITE)
    end
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

    if self.cor then
        self.cor_pass_time = self.cor_pass_time + dt
        if self.cor_pass_time >= self.cor_wait_time then
            self.cor_pass_time = 0
            local state, time = coroutine.resume(self.cor)
            if state then
                if true then
                    self.cor_wait_time = tonumber(time)
                    -- self.cor_wait_time = 0.2
                    print("XWH--->>>1111", self.cor_wait_time)
                end
            else
                self.cor = nil
            end
        end
    end
end

function PlayScene:onExit()
    app:removeEventListener(self.sc_player_move_h)
    app:removeEventListener(self.sc_world_vis_player_h)
    app:removeEventListener(self.sc_one_player_close_h)
end

return PlayScene
