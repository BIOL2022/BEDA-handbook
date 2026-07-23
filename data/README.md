# Weekly schedule data

## Editing `weekly_content.csv`

Each row is one item in the weekly schedule. Keep `week`, `section`, and
`position` unique, and use `position` to set the display order within a
section. Workshop rows remain available to the practical pages but must set
`show_on_schedule` to `FALSE`.

The `note_type` field is required for every `extra` row and must be exactly
`resource`, `assessment`, or `notice`. Leave it blank for lectures, workshops,
and practicals. Do not put labels, icons, arrows, or other presentation markup
in the CSV.

## Notes categories

### Resource

Use `resource` when the main purpose is to give students material to read,
watch, or consult. This includes handbook pages, explanatory Canvas or Ed
posts, books, articles, revision material, and reusable self-check resources.

### Assessment

Use `assessment` when the item is submitted or marked, is a hurdle, or sets an
authoritative rule, deadline, criterion, required output, or submission step
for a named assessment. Name the assessment when the connection may not be
obvious.

### Notice

Use `notice` for course information, announcements, dates, general directions,
events, and unmarked invitations to participate.

## Classification order

Classify an item by what it asks the student to do, not by whether it links to
the handbook, Canvas, Ed, or another site. Apply these questions in order:

1. Is it submitted or marked, a hurdle, or a rule, deadline, required output,
   or submission step for a named assessment? Use `assessment`.
2. Is its main object material to read, watch, or consult? Use `resource`, even
   when students need it for an assessment.
3. Is it operational information, a general direction, an event, or an
   unmarked invitation to participate? Use `notice`.

## Mixed-purpose entries

Split entries that serve distinct purposes. For example, replace “Read the
guide and submit your dataset” with one Resource row for the guide and one
Assessment row for the submission. Do not invent another category.

## Wording and dates

Use concise sentence case. Begin with the student action or named item when
useful, expand unfamiliar acronyms, and name the relevant assessment. Include
only timing that helps students decide what to do.

Use full weekday and month names for calendar dates, for example
“Labour Day — Monday 5 October”. A weekday and time within the current teaching
week may omit the date. Use Sydney time unless another time zone is stated, and
include the year only when the schedule may be read outside its stated year.

Titles must not have surrounding whitespace, HTML tags, Bootstrap icon classes,
destination arrows, or a `Resource:`, `Assessment:`, or `Notice:` prefix.
Ordinary punctuation is allowed.

## URLs

The `url` field accepts:

- a blank value for an unlinked item;
- an absolute `http://` or `https://` URL with a non-empty host; or
- a repository-relative path without a leading slash, optionally followed by a
  query or fragment.

Valid examples include `prerequisites.qmd`,
`module02/202-timeline.qmd#wk6`, and
`https://canvas.sydney.edu.au/courses/74353`.

Do not use surrounding whitespace, other URL schemes, protocol-relative URLs
such as `//example.com`, site-root or filesystem paths, backslashes, control
characters, or HTTP(S) URLs without a host. Validation checks syntax only, so a
future or unpublished destination is allowed.

## Borderline examples

1. A required experimental activity that produces data for Report 1 is
   Assessment. Name Report 1 in the title.
2. A formative quiz is Assessment only when its attempt is required, marked, a
   hurdle, or a required output for a named assessment. A reusable optional
   self-check quiz is Resource; a one-off invitation to try an unmarked
   activity is Notice.
3. A formal hurdle or attendance requirement is Assessment. A reminder to
   record attendance is Notice unless it states the formal requirement.
4. A required draft submission is Assessment. An optional peer-feedback
   activity is Notice.
5. A reading required for an assessment remains Resource because students are
   being directed to material to consult.
6. Revision material is Resource. A message that a week is reserved for
   revision is Notice.
7. An optional assessment-help session is Notice.
8. A page or support thread that states authoritative assessment requirements,
   deadlines, criteria, outputs, or submission steps is Assessment.
   Explanatory or advisory assessment material is Resource.

A Canvas submission link is Assessment, while an optional Canvas self-check may
be Resource. An Ed announcement is Notice, an Ed thread stating authoritative
assessment requirements is Assessment, and an explanatory Ed post is Resource.
Discuss genuinely new cases with the unit coordinator, then add the agreed case
here and to the tests.

## Validation

After editing the schedule, run:

```bash
Rscript tests/test_render_weekly_content_table.R
```
