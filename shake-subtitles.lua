--[[--
Author: cbwces <sknyqbcbw@gmail.com>
Date  : 20220903
--]]--

include("karaskel.lua")
local tr = aegisub.gettext

script_name = tr"Shake Subtitles"
script_description = tr"Make subtitles shape in duration"
script_author = "cbwces"
script_version = "1.0"

function round_during_time(during_time, interval_time)
    local addition
    local mod = during_time % interval_time
    if mod == 0 then
        addition = 0
    else
        addition = interval_time - mod
    end
    return during_time + addition
end

function text_random_shift(shift_kernel, local_seed)
    math.randomseed(os.time() + local_seed)
    local shift = math.random(0, shift_kernel)
    if math.random() > 0.5 then
        return shift_kernel, shift
    else
        return shift, shift_kernel
    end
end

function apply_shape(subtitles, selected_lines)
    local button, result_table = aegisub.dialog.display({{class="label", name="interval_time", label="interval time", x=0, y=0, width=3}, 
                                                         {class="intedit", name="interval_time_value", value=150, x=3, y=0, width=1},
                                                         {class="label", name="random_amplitude", label="random amplitude", x=4, y=0, width=3},
                                                         {class="intedit", name="random_amplitude_value", value=10, x=7, y=0, width=1}},
                                                         {})
    if button == false then
        return false
    end
    local interval_time = result_table.interval_time_value
    local shift_kernel = result_table.random_amplitude_value

    local selected_index = selected_lines[1]
    local selected_line = subtitles[selected_index]

    --comment current line and inplace
    selected_line.comment = true
    selected_line.text = string.format("(effected)%s", selected_line.text)
    subtitles[selected_index] = selected_line
    selected_line.comment = false
    selected_line.text = string.sub(selected_line.text, 11)

    local x, y
    local matched = string.match(selected_line.raw, '\\pos%((%d+,%d+)%)')
    if matched then
        for k, v in string.gmatch(matched, "(%d+),(%d+)") do
            x, y = k, v
            break
        end
    else
        local meta, styles = karaskel.collect_head(subtitles, false)
        karaskel.preproc_line_pos(meta, styles, selected_line)
        x, y = selected_line.x, selected_line.y
    end

    interval_time = interval_time - interval_time % 2 --round interval time
    local start_time, end_time = selected_line.start_time, selected_line.end_time
    local during_time = end_time - start_time
    during_time = round_during_time(during_time, interval_time)

    local x_shift, y_shift, last_x_shift, last_y_shift
    local additional_seed = 0
    local half_duration = interval_time / 2
    local vanilla_text = selected_line.text
    local move_format = "{\\move(%d,%d,%d,%d)}%s"

    x_shift, y_shift = text_random_shift(shift_kernel, additional_seed)
    selected_line.end_time = start_time + half_duration
    selected_line.text = string.format(move_format, x, y, x+x_shift, y+y_shift, vanilla_text)
    subtitles.append(selected_line)

    last_x_shift, last_y_shift = x_shift, y_shift
    for i=half_duration,during_time-interval_time-half_duration,interval_time do

        additional_seed = additional_seed + 1
        x_shift, y_shift = text_random_shift(shift_kernel, additional_seed)
        selected_line.start_time = start_time + i
        selected_line.end_time = start_time + i + half_duration
        selected_line.text = string.format(move_format, x+last_x_shift, y+last_y_shift, x, y, vanilla_text)
        subtitles.append(selected_line)

        selected_line.start_time = start_time + i + half_duration
        selected_line.end_time = start_time + i + interval_time
        selected_line.text = string.format(move_format, x, y, x+x_shift, y+y_shift, vanilla_text)
        subtitles.append(selected_line)

        last_x_shift, last_y_shift = x_shift, y_shift
    end

    selected_line.start_time = start_time + during_time - half_duration
    selected_line.end_time = start_time + during_time
    selected_line.text = string.format(move_format, x+last_x_shift, y+last_y_shift, x, y, vanilla_text)
    subtitles.append(selected_line)
    
    return true
end

function validate_possible(subtitles, selected_lines)
    if (#selected_lines == 1) and (subtitles[selected_lines[1]].comment == false) then
        return true
    else
        return false
    end
end

aegisub.register_macro(script_name, script_description, apply_shape, validate_possible)
