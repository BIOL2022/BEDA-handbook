local canonical_links = {
  ["202-timeline-changelog.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/202-timeline-changelog.html",
  ["201-intro.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/201-intro.html",
  ["203-projects.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/203-projects.html",
  ["205-resources.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/205-resources.html",
  ["204-report1.qmd"] = "https://biol2022.github.io/BEDA-handbook/module02/204-report1.html",
}

local div_functions = {
  ["module2-timeline-meta"] = "module2-timeline-meta",
  ["module2-timeline-support"] = "module2-timeline-support",
  ["module2-timeline-resources"] = "module2-timeline-resources",
  ["module2-timeline-deadline"] = "module2-timeline-deadline",
  ["module2-timeline-table"] = "module2-timeline-table",
}

function Link(link)
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
  for class_name, function_name in pairs(div_functions) do
    if div.classes:includes(class_name) then
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
  if span.classes:includes("module2-week-date") then
    local inlines = pandoc.Inlines({
      pandoc.RawInline("typst", "#module2-week-date["),
    })
    inlines:extend(span.content)
    inlines:insert(pandoc.RawInline("typst", "]"))
    return inlines
  end
end
