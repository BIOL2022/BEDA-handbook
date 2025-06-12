# R/gt_theme.R
library(gt) # Ensure gt is available for the function

# Define a custom gt theme function
gtheme_beda <- function(gt_object) {
  # Ensure the input is a gt table object
  if (!("gt_tbl" %in% class(gt_object))) {
    stop("Input must be a gt table object.")
  }

  gt_object %>%
    # General table options
    tab_options(
      table.width = pct(100),              # Table width to 100%
      table.font.size = px(14),            # Base font size for the table
      table.border.top.style = "none",     # No top border for the table itself
      table.border.bottom.style = "solid", # Solid bottom border for the table
      table.border.bottom.width = px(2),   # Slightly thicker bottom border for emphasis
      table.border.bottom.color = "#333333", # Dark grey for bottom border

      # Heading options (if a heading is present)
      heading.align = "left",
      heading.title.font.size = px(18),    # Font size for title
      heading.subtitle.font.size = px(15), # Font size for subtitle
      heading.border.bottom.style = "none",# No border under heading elements

      # Column label options
      column_labels.font.weight = "bold",
      column_labels.background.color = "white", # Clean white background for column labels
      column_labels.border.top.style = "solid",
      column_labels.border.top.width = px(2),
      column_labels.border.top.color = "#333333",    # Dark grey top border for column labels
      column_labels.border.bottom.style = "solid",
      column_labels.border.bottom.width = px(1),
      column_labels.border.bottom.color = "#D3D3D3", # Lighter grey bottom border for column labels

      # Table body and row options
      table_body.border.top.style = "solid", # Separator line between column labels and table body
      table_body.border.top.width = px(1),
      table_body.border.top.color = "#D3D3D3",
      data_row.padding = px(8),            # Padding for data rows

      # Source notes options (if present)
      source_notes.font.size = px(12),
      source_notes.padding = px(4),

      # Row group options (if present)
      row_group.padding = px(6),
      row_group.font.weight = "bold",
      row_group.background.color = "#f5f5f5", # Light grey background for row groups
      row_group.border.top.style = "solid",
      row_group.border.top.width = px(1),
      row_group.border.top.color = "#D3D3D3",
      row_group.border.bottom.style = "solid",
      row_group.border.bottom.width = px(1),
      row_group.border.bottom.color = "#D3D3D3",
      # Option for row striping color
      row.striping.background_color = "#f9f9f9"
    ) %>%
    # Apply cell borders to the bottom of all body cells for separation
    tab_style(
      style = cell_borders(
        sides = "bottom",
        color = "#E0E0E0", # Very light grey for subtle separation
        weight = px(1)
      ),
      locations = cells_body(columns = everything())
    ) %>%
    # Enable row striping
    opt_row_striping()
}