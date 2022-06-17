--[[--
Author: cbwces <sknyqbcbw@gmail.com>
Date  : 20220503
--]]--

local tr = aegisub.gettext

script_name = tr"Split by Text"
script_description = tr"Split Video by Selected Text"
script_author = "cbwces"
script_version = "1.0"

function padding_zeros(string_to_padding, length)
    local padding_size = length - string.len(string_to_padding)
    return string.rep("0", padding_size) .. string_to_padding
end

function ms_to_timestamp(total_microseconds)
    local remain_microseconds = total_microseconds % 1000
    local microseconds = padding_zeros(tostring(remain_microseconds), 3)
    local total_seconds = math.floor(total_microseconds / 1000)
    local seconds = padding_zeros(tostring(total_seconds % 60), 2)
    local total_minutes = math.floor(total_seconds / 60)
    local minutes = padding_zeros(tostring(total_minutes % 60), 2)
    local hours = tostring(math.floor(total_minutes / 60))
    local seconds_format_time = total_seconds + remain_microseconds / 1000
    return hours .. ":" .. minutes .. ":" .. seconds .. "." .. microseconds, seconds_format_time
end

function request_split_command(split_command, gpu, fade_mode)
    if fade_mode == 'in' then
        if gpu == true then
            local execute_command = string.gsub(split_command, "ffmpeg", "ffmpeg -hwaccel cuda")
            local execute_command = string.gsub(execute_command, "-c copy", "-vf \"fade=t=in:st=0:d=%%f\" -af \"afade=t=in:st=0:d=%%f\" -c:v h264_nvenc")
        else
            local execute_command = string.gsub(split_command, "-c copy", "-vf \"fade=t=in:st=0:d=%%f\" -af \"afade=t=in:st=0:d=%%f\" -c copy")
        end
    elseif fade_mode == 'out' then
        if gpu == true then
            local execute_command = string.gsub(split_command, "ffmpeg", "ffmpeg -hwaccel cuda")
            local execute_command = string.gsub(execute_command, "-c copy", "-vf \"fade=t=out:st=%%f:d=%%f\" -af \"afade=t=out:st=%%f:d=%%f\" -c:v h264_nvenc")
        else
            local execute_command = string.gsub(split_command, "-c copy", "-vf \"fade=t=out:st=%%f:d=%%f\" -af \"afade=t=out:st=%%f:d=%%f\" -c copy")
        end
    else
        local execute_command = split_command
    end
    return execute_command
end

function execute_split(subtitles, selected_lines)
    local save_path = os.getenv("HOME") .. "/output.mp4"
    local gpu = false
    local fadein_value = .0
    local fadeout_value = .0
    local button, result_table = aegisub.dialog.display({{class="textbox", name="save_path", text=save_path, x=0, y=0, width=50}, 
                                                         {class="checkbox", name="gpu", label="GPU", value=false, x=50,y=0, width=1},
                                                         {class="label", name="fadein_label", label="fadein(s)", x=51,y=0, width=1},
                                                         {class="floatedit", name="fadein_value", text="fadein", x=52,y=0, min=.0,width=1},
                                                         {class="label", name="fadeout_label", label="fadeout(s)", x=53,y=0, width=1},
                                                         {class="floatedit", name="fadeout_value", text="fadeout", x=54,y=0, min=.0,width=1}},
                                                         {})
    if button == false then
        return false
    end
    local save_path = result_table.save_path
    local gpu = result_table.gpu
    local fadein_value = result_table.fadein_value
    local fadeout_value = result_table.fadeout_value
    local video_file = string.gsub(aegisub.project_properties().video_file, " ", "\\ ")

    local split_command = "ffmpeg -y -ss %s -to %s -i %s -c copy /tmp/%d.mp4"
    for i=1,#selected_lines,2 do
        local start_index = selected_lines[i]
        local end_index = selected_lines[i+1]
        local start_time = subtitles[start_index].start_time
        local end_time = subtitles[end_index].end_time
        local start_timestamp, seconds_format_start_time = ms_to_timestamp(start_time)
        local end_timestamp, seconds_format_end_time = ms_to_timestamp(end_time)

        if i == 1 and fadein_value ~= .0 then
            local execute_command = request_split_command(split_command, gpu, 'in')
            os.execute(string.format(execute_command, start_timestamp, end_timestamp, video_file, fadein_value, fadein_value, i))
        elseif i == #selected_lines - 1 and fadeout_value ~= .0 then
            local fadeout_start_time = (seconds_format_end_time - seconds_format_start_time) - fadeout_value
            local execute_command = request_split_command(split_command, gpu, 'out')
            os.execute(string.format(execute_command, start_timestamp, end_timestamp, video_file, fadeout_start_time, fadeout_value, fadeout_start_time, fadeout_value, i))
        else
            local execute_command = split_command
            os.execute(string.format(execute_command, start_timestamp, end_timestamp, video_file, i))
        end
    end

    local n_split = #selected_lines / 2
    local concat_command = "ffmpeg -y "
    if gpu == true then
        local concat_command = concat_command .. "-hwaccel cuda "
    end
    for i=1,#selected_lines,2 do
        local concat_command = concat_command .. string.format("-i /tmp/%d.mp4 ", i)
    end
    local concat_command = concat_command .. "-filter_complex \""
    for i=0,n_split-1 do
        local concat_command = concat_command .. string.format("[%d:v] [%d:a] ", i, i)
    end
    local concat_command = concat_command .. string.format("concat=n=%s:v=1:a=1 [v] [a]\" -map \"[v]\" -map \"[a]\" ", n_split)
    if gpu == true then
        local concat_command = concat_command .. "-c:v h264_nvenc "
    end
    local concat_command = concat_command .. save_path
    os.execute(concat_command)
    return true
end

function validate_split(subtitles, selected_lines)
    if #selected_lines % 2 == 0 and #selected_lines ~= 0 and aegisub.project_properties().video_file ~= "" then
        return true
    else
        return false
    end
end

aegisub.register_macro(script_name, script_description, execute_split, validate_split)
