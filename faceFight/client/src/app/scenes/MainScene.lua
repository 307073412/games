
local MainScene = class("MainScene", function()
    return display.newScene("MainScene")
end)

function MainScene:ctor()
    local bg = display.newSprite("fenglingshu_bg.jpg", display.cx, display.cy)
    local scaleX = display.width / bg:getContentSize().width
    local scaleY = display.height / bg:getContentSize().height
    bg:setScaleX(scaleX)
    bg:setScaleY(scaleY)
    self:addChild(bg, -1)

    cc.ui.UILabel.new({
            UILabelType = 2, text = "请输入名字", size = 64})
        :align(display.CENTER, display.cx, display.cy + 90)
        :addTo(self)        

    self.lbl_server_link_state = cc.ui.UILabel.new({
            UILabelType = 2, text = "", size = 19})
        :align(display.TOP_LEFT, display.left, display.top)
        :addTo(self)

    self.editBox2 = cc.ui.UIInput.new({
        image = "EditBoxBg.png",
        size = cc.size(400, 96),
        x = display.cx,
        y = display.cy,
        listener = function(event, editbox)
            if event == "began" then
                -- self:onEditBoxBegan(editbox)
            elseif event == "ended" then
                self:onEditBoxEnded(editbox)
            elseif event == "return" then
                -- self:onEditBoxReturn(editbox)
            elseif event == "changed" then
                -- self:onEditBoxChanged(editbox)
            else
                printf("EditBox event %s", tostring(event))
            end
        end
    })
    self:addChild(self.editBox2)

    self.editBox2:setText("阿呜")

    cc.ui.UIPushButton.new({normal = "toggle_104_normal.png", pressed = "toggle_104_select.png"})
        :onButtonClicked(handler(self, self.onClickStart))
        :align(display.CENTER, display.cx, display.cy - 80)
        :setButtonLabel("normal", display.newTTFLabel({text = "开始游戏", size = 22, font = "", color = cc.c3b(0xff, 0xff, 0x00)}))
        :addTo(self)

    self.server_opt_btn = cc.ui.UIPushButton.new({normal = "toggle_104_normal.png", pressed = "toggle_104_select.png"})
        :onButtonClicked(function ()
            if app:isConnected() then
            	app:closeConnect()
            else
                app:connectServer()
            end
        end)
        :align(display.BOTTOM_RIGHT, display.right - 50, 25)
        :setButtonLabel("normal", display.newTTFLabel({text = "", size = 20, font = "", color = cc.c3b(0xff, 0xff, 0x00)}))
        :addTo(self)
end

function MainScene:onClickStart()
	local createName = self.editBox2:getText()
	if createName ~= "" then
		app:createPlayer({name = createName})
	end
end

function MainScene:onEditBoxEnded(sender)
	printInfo("text:" .. sender:getText())
end

function MainScene:onEnter()
    self.create_player_return_handle = app:addEventListener("sc_create_player_return", handler(self, self.onMainPlayerData))
    self.server_state_change_handle = app:addEventListener("server_state_change", handler(self, self.onServerStateChange))
    
    app:connectServer()
end

function MainScene:onExit()
    app:removeEventListener(self.create_player_return_handle)
	app:removeEventListener(self.server_state_change_handle)
end

function MainScene:onServerStateChange(data)
    printInfo("server state:" .. data.server_state)
    local str = "未连接"
    local btn_str = "连接服务器"
    if data.server_state == "connected" then
        str = "已连接"
        btn_str = "断开连接"
    elseif data.server_state == "close" then
    elseif data.server_state == "fail" then
        str = "连接失败"
    elseif data.server_state == "connecting" then
        str = "连接中..."
    end
    self.lbl_server_link_state:setString(str)
    self.server_opt_btn:setButtonLabelString("normal", btn_str)
end

function MainScene:onMainPlayerData(data)
	app.player_data = data.param

    local scene = require("app.scenes.PlayScene").new()
    display.replaceScene(scene)
end

return MainScene
