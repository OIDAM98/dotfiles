function Manager:render(area)
	local chunks = self:layout(area)

	local bar = function(c, x, y)
		x, y = math.max(0, x), math.max(0, y)
		return ui.Bar(ui.Rect { x = x, y = y, w = ya.clamp(0, area.w - x, 1), h = math.min(1, area.h) }, ui.Bar.TOP)
			:symbol(c)
	end

 	return ya.flat {
 		-- Borders
		ui.Border(area, ui.Border.ALL):type(ui.Border.ROUNDED),
		ui.Bar(chunks[1], ui.Bar.RIGHT),
		ui.Bar(chunks[3], ui.Bar.LEFT),

		bar("┬", chunks[1].right - 1, chunks[1].y),
		bar("┴", chunks[1].right - 1, chunks[1].bottom - 1),
		bar("┬", chunks[2].right, chunks[2].y),
		bar("┴", chunks[2].right, chunks[1].bottom - 1),

 		-- Parent
		Parent:render(chunks[1]:padding(ui.Padding.xy(1))),
 		-- Current
		Current:render(chunks[2]:padding(ui.Padding.y(1))),
 		-- Preview
		Preview:render(chunks[3]:padding(ui.Padding.xy(1))),
 	}
 end

function Header:host()
	if ya.target_family() ~= "unix" then
		return ui.Line {}
	end
	return ui.Span(ya.user_name() .. "@" .. ya.host_name() .. ":"):fg("blue")
end

function Header:render(area)
	local chunks = self:layout(area)

	local left = ui.Line { self:host(), self:cwd() }
	local right = ui.Line { self:tabs() }
	return {
		ui.Paragraph(chunks[1], { left }),
		ui.Paragraph(chunks[2], { right }):align(ui.Paragraph.RIGHT),
	}
end
