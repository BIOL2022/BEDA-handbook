function Div(div)
  if FORMAT ~= "typst" then
    return nil
  end

  local classes = {}
  local is_margin_note = false

  for _, class in ipairs(div.classes) do
    if class == "column-margin" then
      is_margin_note = true
    else
      table.insert(classes, class)
    end
  end

  if not is_margin_note then
    return nil
  end

  local first_block = div.content[1]

  if first_block and
      (first_block.t == "Para" or first_block.t == "Plain") then
    local inlines = {
      pandoc.RawInline(
        "typst",
        '#text(fill: rgb("#482878"))[ⓘ]'
      ),
      pandoc.Space(),
    }

    for _, inline in ipairs(first_block.content) do
      if inline.t ~= "RawInline" or inline.format ~= "html" then
        table.insert(inlines, inline)
      end
    end

    first_block.content = inlines
  end

  div.classes = classes
  return div
end
