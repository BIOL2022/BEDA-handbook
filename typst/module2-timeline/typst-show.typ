#let beda-green = rgb("#0f6b5b")
#let beda-maroon = rgb("#6b210f")
#let beda-purple = rgb("#482878")
#let beda-cream = rgb("#fbfaf6")
#let beda-ink = rgb("#142326")
#let beda-muted = rgb("#536366")
#let beda-rule = rgb("#c9c5b8")
#let beda-header = rgb("#edf4f5")
#let beda-support = rgb("#f1f7f5")
#let beda-deadline = rgb("#f8eef1")

#let module2-timeline-meta(body) = block(
  below: 10pt,
)[
  #set text(size: 9.3pt, fill: beda-muted)
  #body
]

#let module2-timeline-support(body) = block(
  width: 100%,
  below: 5pt,
  breakable: false,
  fill: beda-support,
  inset: (left: 10pt, right: 10pt, top: 8pt, bottom: 8pt),
  stroke: (left: 3pt + beda-green),
)[#body]

#let module2-timeline-resources(body) = block(
  width: 100%,
  below: 10pt,
)[
  #set text(size: 9.4pt)
  #body
]

#let module2-timeline-deadline(body) = block(
  width: 100%,
  below: 13pt,
  breakable: false,
  fill: beda-deadline,
  inset: (left: 10pt, right: 10pt, top: 8pt, bottom: 8pt),
  stroke: (left: 3pt + beda-maroon),
)[
  #set text(weight: "bold", fill: beda-maroon)
  #body
]

#let module2-week-date(body) = text(
  size: 9.3pt,
  fill: beda-muted,
  [#linebreak()#body],
)

#let module2-timeline-table(body) = block(width: 100%)[
  #set text(size: 9.5pt)
  #set par(leading: 0.58em, spacing: 0.35em)
  #show table: set table(
    inset: (x: 5.5pt, y: 5.5pt),
    align: left + top,
    stroke: (x: none, y: 0.45pt + beda-rule),
  )
  #show table.cell.where(y: 0): set table.cell(fill: beda-header)
  #show table.cell: set table.cell(breakable: false)
  #show list: set list(
    indent: 1.05em,
    body-indent: 0.5em,
    spacing: 0.25em,
  )
  #body
]

#let module2-timeline-document(title: none, authors: (), doc) = {
  set document(title: title) if title != none
  set document(author: authors.join(", ")) if authors != ()
  set text(
    lang: "en",
    font: ("Libertinus Serif", "New Computer Modern"),
    size: 10pt,
    fill: beda-ink,
  )
  set par(leading: 0.64em, spacing: 0.72em, justify: false)
  set page(
    paper: "a4",
    margin: (top: 20mm, bottom: 20mm, left: 18mm, right: 18mm),
    fill: beda-cream,
    header: context [
      #set text(size: 8.5pt, fill: beda-muted)
      #if counter(page).get().first() > 1 [
        BIOL2022 Unit Handbook
        #h(1fr)
        Module 2 timeline
      ]
    ],
    footer: context [
      #set text(size: 8.5pt, fill: beda-muted)
      Semester 2, 2026
      #h(1fr)
      Page #counter(page).display()
    ],
  )
  show link: link => text(fill: beda-purple, underline(link))
  show heading.where(level: 1): heading => {
    text(size: 26pt, weight: "bold", fill: beda-purple, heading.body)
    v(3pt)
  }

  if title != none {
    heading(level: 1, numbering: none, outlined: false, title)
  }

  doc
}

#show: doc => module2-timeline-document(
$if(title)$
  title: [$title$],
$endif$
  authors: (
$for(by-author)$
    "$it.name.literal$",
$endfor$
  ),
  doc,
)
