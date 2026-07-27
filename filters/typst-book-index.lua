function Header(header)
  if FORMAT == "typst" and
      header.level == 1 and
      header.identifier == "beda-handbook" then
    return {}
  end
end
