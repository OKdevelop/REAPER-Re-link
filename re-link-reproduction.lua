local sep = package.config:sub(1,1)

local ret, directory = reaper.GetUserInputs("Root Folder Selection", 1, "Enter root folder full path:", "")
if not ret or directory == "" then
    reaper.ShowMessageBox("Canceled.", "Re-link", 0)
    return
end

if directory:sub(-1) ~= sep then
  directory = directory .. sep
end

function scan_dir_recursive(dir)
  local files = {}
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(dir, i)
    if not file then break end
    files[file] = dir .. file
    i = i + 1
  end
  i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(dir, i)
    if not subdir then break end
    local subfiles = scan_dir_recursive(dir .. subdir .. sep)
    for k, v in pairs(subfiles) do
      files[k] = v
    end
    i = i + 1
  end
  return files
end

function relink_missing_items(file_map)
  local num_items = reaper.CountMediaItems("")
  local relinked = 0
  for i = 0, num_items - 1 do
    local item = reaper.GetMediaItem("", i)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local source = reaper.GetMediaItemTake_Source(take)
      local filename = reaper.GetMediaSourceFileName(source, "")
      if filename == "" or not reaper.file_exists(filename) then
        local just_name = filename:match("[^"..sep.."]+$")
        local new_path = file_map[just_name]
        if new_path then
          reaper.BR_SetTakeSourceFromFile(take, new_path, true)
          relinked = relinked + 1
        end
      end
    end
  end
  return relinked
end

reaper.Undo_BeginBlock()
local file_map = scan_dir_recursive(directory)
local count = relink_missing_items(file_map)
reaper.Undo_EndBlock("Complete Re-link", -1)

reaper.ShowMessageBox("Complete Re-link: " .. tostring(count) .. " files fixed.", "Success", 0)