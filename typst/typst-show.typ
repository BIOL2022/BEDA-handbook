#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#let beda-green = rgb("#0f6b5b")
#let beda-maroon = rgb("#6b210f")
#let beda-purple = rgb("#482878")
#let beda-cream = rgb("#fbfaf6")
#let beda-ink = rgb("#142326")
#let beda-muted = rgb("#536366")

#let beda-cover = box(
  width: 210mm,
  height: 297mm,
  fill: beda-cream,
)[
  #set text(font: "Libertinus Serif", fill: beda-ink)

  #place(top + left, dx: 21mm, dy: 20mm)[
    #text(
      size: 10pt,
      weight: "semibold",
      fill: beda-green,
    )[The University of Sydney]
  ]

  #place(top + left, dx: 21mm, dy: 42mm)[
    #rect(width: 1.5mm, height: 150mm, fill: beda-maroon)
  ]

  #place(top + left, dx: 31mm, dy: 45mm)[
    #block(width: 148mm)[
      #set par(leading: 0.45em)
      #text(size: 29pt, weight: "bold")[
        BIOL2022 \
        Biology Experimental \
        Design and Analysis
      ]
      #v(4mm)
      #box(width: 27mm, height: 27mm)[
        #image(
          "assets/bedalogo.png",
          width: 100%,
          height: 100%,
          fit: "contain",
          alt: "BEDA logo",
        )
      ]
      #v(5mm)
      #line(length: 27mm, stroke: 1.2pt + beda-maroon)
      #v(8mm)
      #text(size: 17pt, weight: "medium", fill: beda-maroon)[
        Unit Handbook
      ]
      #v(27mm)
      #set par(leading: 0.65em)
      #text(size: 10.5pt, fill: beda-muted)[
$for(by-author)$
        $it.name.literal$ \
$endfor$
      ]
    ]
  ]

  #place(bottom + left, dx: 31mm, dy: -20mm)[
    #text(size: 10pt, weight: "bold", fill: beda-green)[
      Semester $edition-semester$ · $edition-year$
    ]
  ]
]

#let beda-colophon(body) = {
  metadata((
    kind: "beda-colophon",
    body: {
      set text(font: "Libertinus Serif", size: 9pt, fill: black)
      set heading(outlined: false, numbering: none)
      set par(
        justify: false,
        leading: 0.7em,
        spacing: 0.8em,
        first-line-indent: 0pt,
      )
      show text: set text(fill: black)
      show heading.where(level: 1): it => {
        text(size: 16pt, weight: "bold", fill: black)[#it.body]
        v(0.55em)
        line(length: 19mm, stroke: 0.9pt + beda-maroon)
        v(0.75em)
      }
      show heading.where(level: 2): it => block(
        above: 0.85em,
        below: 0.14em,
      )[
        #text(size: 9.6pt, weight: "semibold", fill: black)[#it.body]
      ]
      body
    },
  ))
}

#show: doc => {
  book(
    title: [],
    subtitle: [],
    author: "",
$if(date)$
    date: "$date$",
$endif$
$if(lang)$
    lang: "$lang$",
$endif$
    main-color: beda-purple,
    logo: none,
    cover: beda-cover,
    cover-background: none,
    copyright: context {
      let colophons = query(metadata).filter(
        item => item.value.at("kind", default: none) == "beda-colophon",
      )
      if colophons.len() > 0 {
        set page(
          margin: (left: 42mm, right: 42mm, top: 40mm, bottom: 28mm),
          fill: beda-cream,
          footer: none,
        )
        block(
          width: 100%,
          height: 100%,
        )[
          #align(top + left, colophons.first().value.body)
        ]
      }
    },
    heading-style: 2,
    font-size: 10.5pt,
    first-line-indent: false,
$if(toc-depth)$
    outline-depth: $toc-depth$,
$endif$
$if(lof)$
    list-of-figure-title: "$if(crossref.lof-title)$$crossref.lof-title$$else$$crossref-lof-title$$endif$",
$endif$
$if(lot)$
    list-of-table-title: "$if(crossref.lot-title)$$crossref.lot-title$$else$$crossref-lot-title$$endif$",
$endif$
$if(margin-geometry)$
    padded-heading-number: false,
$endif$
    {
      show par: set par(
        justify: false,
        leading: 0.68em,
        spacing: 1.5em,
        first-line-indent: 0pt,
      )
      show heading.where(level: 1): it => {
        pagebreak(to: "odd")
        counter(figure.where(kind: image)).update(0)
        counter(figure.where(kind: table)).update(0)
        counter(math.equation).update(0)
        set par(justify: false)
        align(right)[
          #if it.numbering != none {
            text(size: 44pt, weight: "bold", fill: beda-purple)[
              #counter(heading).display("1")
            ]
            v(-0.8em)
          }
          #text(size: 23pt, weight: "bold", fill: beda-purple)[#it.body]
        ]
        v(0.45em)
        line(length: 100%, stroke: 1pt + beda-purple)
        v(1.2em)
      }
      show heading.where(level: 2): set text(fill: beda-purple)
      show heading.where(level: 2): set block(below: 0.5em)
      show enum: set enum(
        indent: 1.15em,
        body-indent: 0.75em,
        spacing: 0.65em,
      )
      show enum: set block(above: 1.5em, below: 1.5em)
      show list: set list(
        indent: 1.15em,
        body-indent: 0.75em,
        spacing: 0.65em,
      )
      show list: set block(above: 1.5em, below: 1.5em)

      doc
    },
  )
}

#show: result => {
  set document(
$if(title)$
    title: [$title$],
$endif$
$if(by-author)$
    author: (
$for(by-author)$
      "$it.name.literal$".replace("~", " "),
$endfor$
    ),
$endif$
  )
  result
}

$if(margin-geometry)$
#import "@preview/marginalia:0.3.1" as marginalia

#show: marginalia.setup.with(
  inner: (
    far: $margin-geometry.inner.far$,
    width: $margin-geometry.inner.width$,
    sep: $margin-geometry.inner.separation$,
  ),
  outer: (
    far: $margin-geometry.outer.far$,
    width: $margin-geometry.outer.width$,
    sep: $margin-geometry.outer.separation$,
  ),
  top: $if(margin.top)$$margin.top$$else$1.25in$endif$,
  bottom: $if(margin.bottom)$$margin.bottom$$else$1.25in$endif$,
  book: true,
  clearance: $margin-geometry.clearance$,
)
$endif$
