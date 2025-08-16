# Read the content of the source file
lines <- readLines("module02/202-timeline.qmd")

# Extract the relevant lines
timeline_content <- lines[42:222]

# Remove the container divs but keep the content
# This regex looks for lines that start with :::
cleaned_content <- timeline_content[!grepl("^:::", timeline_content)]

# Join the cleaned lines back into a single string
final_content <- paste(cleaned_content, collapse = "\n")

# Create the YAML header
yaml_header <- '---
title: "Module 2 Timeline"
format:
  typst:
    toc: false
    number-sections: false
---
'

# Combine the header and the cleaned content
output_content <- paste(yaml_header, final_content, sep = "\n")

# Write to the new file
writeLines(output_content, "module02/timeline-for-pdf.qmd")

cat("Successfully created module02/timeline-for-pdf.qmd\n")
