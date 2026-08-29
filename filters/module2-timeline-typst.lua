local canonical_links = {
  ["201-overview.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/201-overview.html",
  ["200-welcome.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/200-welcome.html",
  ["203-projects.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/203-projects.html",
  ["205-resources.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/205-resources.html",
  ["204-report1.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/204-report1.html",
}

local div_functions = {
  ["module2-timeline-support"] = "module2-timeline-support",
  ["module2-timeline-resources"] = "module2-timeline-resources",
  ["module2-timeline-deadline"] = "module2-timeline-deadline",
  ["module2-timeline-table"] = "module2-timeline-table",
}

-- Relative column widths for the Module 2 timeline table. The first column is
-- kept just wide enough for the longest week/date label; the saved space goes
-- to the two activity columns, which carry most of the text.
local timeline_col_widths = { 0.22, 0.39, 0.39 }

local function adjust_timeline_columns(block)
  local specs = block.colspecs
  if not specs or #specs < 3 then
    return
  end
  for i = 1, 3 do
    local spec = specs[i]
    if type(spec) ~= "table" then
      return
    end
    local alignment = spec[1] or "AlignLeft"
    specs[i] = { alignment, timeline_col_widths[i] }
  end
  block.colspecs = specs
end

function Link(link)
  if FORMAT ~= "typst" then
    return nil
  end

  local path, suffix = link.target:match("^([^?#]+)(.*)$")
  if path then
    path = path:gsub("^%./", "")
  end
  if path and canonical_links[path] then
    link.target = canonical_links[path] .. suffix
  end
  return link
end

function Div(div)
  if FORMAT ~= "typst" then
    return nil
  end

  for class_name, function_name in pairs(div_functions) do
    if div.classes:includes(class_name) then
      if class_name == "module2-timeline-table" then
        for _, block in ipairs(div.content) do
          if block.t == "Table" then
            adjust_timeline_columns(block)
          end
        end
      end

      if class_name == "module2-timeline-deadline" then
        for _, block in ipairs(div.content) do
          if block.t == "Para" or block.t == "Plain" then
            for index, inline in ipairs(block.content) do
              if inline.t == "SoftBreak" then
                block.content[index] = pandoc.RawInline("typst", "#h(1fr)")
              end
            end
          end
        end
      end

      local blocks = pandoc.Blocks({
        pandoc.RawBlock("typst", "#" .. function_name .. "["),
      })
      blocks:extend(div.content)
      blocks:insert(pandoc.RawBlock("typst", "]"))
      return blocks
    end
  end
end

function Span(span)
  if FORMAT ~= "typst" then
    return nil
  end

  if span.classes:includes("module2-week-date") then
    local inlines = pandoc.Inlines({
      pandoc.RawInline("typst", "#module2-week-date["),
    })
    inlines:extend(span.content)
    inlines:insert(pandoc.RawInline("typst", "]"))
    return inlines
  end
end
