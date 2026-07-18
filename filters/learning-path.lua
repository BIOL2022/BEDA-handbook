local data_path = "data/weekly_content.csv"
local cached_rows = nil
local root_override = nil

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function has_class(element, class_name)
  for _, value in ipairs(element.classes) do
    if value == class_name then
      return true
    end
  end
  return false
end

local function text_inlines(value)
  local inlines = pandoc.Inlines({})
  for word in value:gmatch("%S+") do
    if #inlines > 0 then
      inlines:insert(pandoc.Space())
    end
    inlines:insert(pandoc.Str(word))
  end
  return inlines
end

local function slash_path(value)
  return value:gsub("\\", "/"):gsub("/+$", "")
end

local function project_directory()
  if root_override ~= nil then
    return root_override
  end
  local directory = os.getenv("QUARTO_PROJECT_DIR")
  if directory == nil or directory == "" then
    return nil
  end
  return slash_path(directory)
end

local function is_absolute_path(value)
  return value:sub(1, 1) == "/" or value:match("^%a:/") ~= nil
end

local function normalise_path(value)
  local path = slash_path(value)
  path = path:gsub("^%./", "")

  local root = project_directory()
  if root ~= nil and path:sub(1, #root + 1) == root .. "/" then
    path = path:sub(#root + 2)
  end

  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #parts > 0 then
        table.remove(parts)
      end
    elseif part ~= "." and part ~= "" then
      table.insert(parts, part)
    end
  end
  return table.concat(parts, "/")
end

local function resolve_data_path()
  if is_absolute_path(data_path) then
    return data_path
  end
  local root = project_directory() or pandoc.system.get_working_directory()
  return slash_path(root) .. "/" .. data_path
end

local function directory_name(path)
  return path:match("^(.*)/[^/]+$") or ""
end

local function split_path(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  return parts
end

local function relative_target(current_path, target)
  if target:match("^[%a][%w+.-]*:") or target:sub(1, 1) == "#" then
    return target
  end

  local from_parts = split_path(directory_name(current_path))
  local target_parts = split_path(normalise_path(target))
  local common = 0
  while (
    common < #from_parts and
    common < #target_parts and
    from_parts[common + 1] == target_parts[common + 1]
  ) do
    common = common + 1
  end

  local result = {}
  for _ = common + 1, #from_parts do
    table.insert(result, "..")
  end
  for index = common + 1, #target_parts do
    table.insert(result, target_parts[index])
  end

  if #result == 0 then
    return "."
  end
  return table.concat(result, "/")
end

local function parse_csv(content)
  local rows = {}
  local row = {}
  local field = {}
  local in_quotes = false
  local index = 1

  local function finish_field()
    table.insert(row, table.concat(field))
    field = {}
  end

  local function finish_row()
    finish_field()
    table.insert(rows, row)
    row = {}
  end

  while index <= #content do
    local character = content:sub(index, index)
    if in_quotes then
      if character == '"' then
        if content:sub(index + 1, index + 1) == '"' then
          table.insert(field, '"')
          index = index + 1
        else
          in_quotes = false
        end
      else
        table.insert(field, character)
      end
    elseif character == '"' then
      in_quotes = true
    elseif character == "," then
      finish_field()
    elseif character == "\r" then
      if content:sub(index + 1, index + 1) == "\n" then
        index = index + 1
      end
      finish_row()
    elseif character == "\n" then
      finish_row()
    else
      table.insert(field, character)
    end
    index = index + 1
  end

  if in_quotes then
    error("weekly_content.csv contains an unterminated quoted field.", 0)
  end
  if #field > 0 or #row > 0 then
    finish_row()
  end

  return rows
end

local function read_rows()
  if cached_rows ~= nil then
    return cached_rows
  end

  local resolved_path = resolve_data_path()
  local file, open_error = io.open(resolved_path, "rb")
  if file == nil then
    error("Could not open learning-path data '" .. data_path .. "': " .. open_error, 0)
  end
  local content = file:read("*a")
  file:close()

  local csv_rows = parse_csv(content)
  if #csv_rows < 2 then
    error("Learning-path data has no resource rows.", 0)
  end

  local headers = csv_rows[1]
  if headers[1] ~= nil then
    headers[1] = headers[1]:gsub("^\239\187\191", "")
  end
  local required = { "week", "section", "title", "url" }
  local header_positions = {}
  for index, header in ipairs(headers) do
    header_positions[trim(header)] = index
  end
  for _, header in ipairs(required) do
    if header_positions[header] == nil then
      error("Learning-path data is missing column '" .. header .. "'.", 0)
    end
  end

  cached_rows = {}
  for row_index = 2, #csv_rows do
    local values = csv_rows[row_index]
    local resource = {}
    for _, header in ipairs(required) do
      resource[header] = trim(values[header_positions[header]] or "")
    end
    if resource.week ~= "" or resource.section ~= "" or resource.title ~= "" or resource.url ~= "" then
      table.insert(cached_rows, resource)
    end
  end

  return cached_rows
end

local function rows_for_week(week)
  local rows = {}
  for _, resource in ipairs(read_rows()) do
    if resource.week == week then
      table.insert(rows, resource)
    end
  end
  return rows
end

local function single_section(rows, week, section)
  local matches = {}
  for _, resource in ipairs(rows) do
    if resource.section == section then
      table.insert(matches, resource)
    end
  end
  if #matches ~= 1 then
    error(
      "Week " .. week .. " learning path requires exactly one " .. section .. " row.",
      0
    )
  end
  return matches[1]
end

local function current_input_path()
  local source_path = nil
  if (
    quarto ~= nil and
    quarto.doc ~= nil and
    quarto.doc.input_file ~= nil and
    quarto.doc.input_file ~= ""
  ) then
    source_path = quarto.doc.input_file
  else
    local input_files = PANDOC_STATE.input_files or {}
    if #input_files ~= 1 then
      error("A learning-path page must be rendered from exactly one input file.", 0)
    end
    source_path = input_files[1]
  end
  local input_path = slash_path(source_path)
  if not is_absolute_path(input_path) then
    input_path = slash_path(pandoc.system.get_working_directory()) .. "/" .. input_path
  end
  return normalise_path(input_path)
end

local function configure(meta)
  if meta["learning-path-root"] ~= nil then
    local configured_root = pandoc.utils.stringify(meta["learning-path-root"])
    if is_absolute_path(configured_root) then
      root_override = slash_path(configured_root)
    else
      root_override = normalise_path(
        slash_path(pandoc.system.get_working_directory()) .. "/" .. configured_root
      )
      if not is_absolute_path(root_override) then
        root_override = slash_path(pandoc.system.get_working_directory())
      end
    end
  end
  if meta["learning-path-data"] ~= nil then
    data_path = pandoc.utils.stringify(meta["learning-path-data"])
    cached_rows = nil
  end
end

local function learning_path_div(div)
  if not has_class(div, "week-learning-path") then
    return nil
  end

  local week = trim(div.attributes.week or "")
  if week == "" then
    error("A week-learning-path marker requires a week attribute.", 0)
  end

  local week_rows = rows_for_week(week)
  local resources = {
    single_section(week_rows, week, "lecture"),
    single_section(week_rows, week, "workshop"),
    single_section(week_rows, week, "practical")
  }

  local urls = {}
  for _, resource in ipairs(resources) do
    local normalised_url = normalise_path(resource.url)
    if resource.url == "" or urls[normalised_url] then
      error("Week " .. week .. " learning path URLs must be present and unique.", 0)
    end
    urls[normalised_url] = true
  end

  local current_path = current_input_path()
  local current_matches = 0
  local current_index = nil
  for index, resource in ipairs(resources) do
    if normalise_path(resource.url) == current_path then
      current_matches = current_matches + 1
      current_index = index
    end
  end
  if current_matches ~= 1 then
    error(
      "Current page '" .. current_path .. "' does not match exactly one Week " ..
        week .. " learning-path URL.",
      0
    )
  end

  local prefixes = {
    "Lectures — learn the ideas: ",
    "Workshop — practise the fundamentals: ",
    "Practical — apply them: "
  }
  local items = {}
  for index, resource in ipairs(resources) do
    local label = prefixes[index] .. resource.title
    local content
    if index == current_index then
      content = text_inlines(label .. " — you are here")
    else
      content = pandoc.Inlines({
        pandoc.Link(
          text_inlines(label),
          relative_target(resources[current_index].url, resource.url)
        )
      })
    end
    table.insert(items, { pandoc.Plain(content) })
  end

  return {
    pandoc.Header(
      2,
      text_inlines("Week " .. week .. " learning path"),
      pandoc.Attr("week-" .. week .. "-learning-path")
    ),
    pandoc.OrderedList(items)
  }
end

function Pandoc(document)
  configure(document.meta)
  return document:walk({ Div = learning_path_div })
end
