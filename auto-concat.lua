--[[--
Author: cbwces <sknyqbcbw@gmail.com>
Date  : 20220617
--]]--

local tr = aegisub.gettext

script_name = tr"Auto Concat"
script_description = tr"Auto concat if time interval less than n milliseconds"
script_author = "cbwces"
script_version = "1.0.0"

function execute_concat(subtitles, selected_lines)
    local button, result_table = aegisub.dialog.display({{class="label", name="interval_label", label="interval", x=0, y=0, width=5},
                                                         {class="intedit", name="interval_value", text="interval value", value=400, min=0, x=5, y=0, width=10}},
                                                        {})
    if button == false then
        return false
    end
    local interval_value = result_table.interval_value
    for i=2,#selected_lines do
        local prev_line = subtitles[selected_lines[i-1]]
        local prev_line_end_time = prev_line.end_time
        local next_line = subtitles[selected_lines[i]]
        local next_line_start_time = next_line.start_time
        if next_line_start_time - prev_line_end_time <= interval_value then
            prev_line.end_time = next_line_start_time
            subtitles[selected_lines[i-1]] = prev_line
        end
    end
end

function validate_concat(subtitles, selected_lines)
    if #selected_lines < 2 then
        return false
    else
        return true
    end
end

aegisub.register_macro(script_name, script_description, execute_concat, validate_concat)
