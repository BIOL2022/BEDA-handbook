-- Keep course destinations in _semester.json, including links inside raw HTML.
local courses = {}

local function resolve_course_url(url)
  for name, base in pairs(courses) do
    local prefix = name .. ":"
    if url:sub(1, #prefix) == prefix then
      return base .. url:sub(#prefix + 1)
    end
  end
  return url
end

return {
  {
    Meta = function()
      -- Single-file previews may not provide quarto.project.directory.
      local settings_path = pandoc.path.join({
        pandoc.path.directory(PANDOC_SCRIPT_FILE), "..", "_semester.json"
      })
      local file = assert(io.open(settings_path, "r"))
      local settings = pandoc.json.decode(file:read("*a"))
      file:close()
      for _, item in ipairs(settings.website.navbar.right) do
        courses[item.text:lower()] = item.href:gsub("/$", "")
      end
    end
  },
  {
    Link = function(link)
      link.target = resolve_course_url(link.target)
      return link
    end,
    RawBlock = function(block)
      if block.format == "html" then
        block.text = block.text:gsub('(href=")([^"%s]+)(")', function(before, url, after)
          return before .. resolve_course_url(url) .. after
        end)
      end
      return block
    end,
    RawInline = function(inline)
      if inline.format == "html" then
        inline.text = inline.text:gsub('(href=")([^"%s]+)(")', function(before, url, after)
          return before .. resolve_course_url(url) .. after
        end)
      end
      return inline
    end
  }
}
