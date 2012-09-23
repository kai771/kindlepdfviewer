require "widget"
require "font"

InfoMessage = {
}

function InfoMessage:show(text)
	Debug("# InfoMessage ", text)
	local dialog = CenterContainer:new({
		dimen = { w = G_width, h = G_height },
		FrameContainer:new({
			margin = 2,
			background = 0,
			HorizontalGroup:new({
				align = "center",
				ImageWidget:new({
					file = "resources/info-i.png"
				}),
				Widget:new({
					dimen = { w = 10, h = 0 }
				}),
				TextWidget:new({
					text = text,
					face = Font:getFace("infofont", 30)
				})
			})
		})
	})
	dialog:paintTo(fb.bb, 0, 0)
	dialog:free()
	fb:refresh(0)
end

function showInfoMsgWithDelay(text, msec)
	local delayms = msec or 1000
	Screen:saveCurrentBB()

	InfoMessage:show(text)
	fb:refresh(1)

	-- eat the first key release event
	local ev = input.waitForEvent()
	adjustKeyEvents(ev)
	repeat
		ok = pcall( function()
			ev = input.waitForEvent(delayms*1000)
			adjustKeyEvents(ev)
		end)
	until not ok or ev.value == EVENT_VALUE_KEY_PRESS

	Screen:restoreFromSavedBB()
	fb:refresh(1)
end
