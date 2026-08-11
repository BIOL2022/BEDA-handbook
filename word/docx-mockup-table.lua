-- Apply the isolated "MockupInfoTable" Word table style (defined in
-- word/beda-reference.docx with explicit black outer + inner borders) to any
-- table wrapped in a `::: {.mockup-info-table}` div. Pandoc's DOCX writer reads
-- `custom-style` from the Table AST node and emits <w:tblStyle w:val="...">,
-- which is the only way to target a custom table style for one table (a div or
-- caption `custom-style` does not propagate to <w:tblStyle> under Quarto).
-- No-op for tables outside the div and harmless for non-docx output.
function Div(div)
  if div.classes:includes("mockup-info-table") then
    return pandoc.walk_block(div, {
      Table = function(tbl)
        tbl.attributes["custom-style"] = "MockupInfoTable"
        return tbl
      end
    })
  end
end
