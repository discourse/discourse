styleguide revamp improvements

- add a page for styling customizations that includes CSS snippets that get turned on/off for:
  - glassy header OK
  - alternative sidebar active/hover styles OK
  - borderless header and sidebar OK
  - alternative list background
- integrate theme site settings
- add cheap font choices for now (using Google Fonts, but in the future, transition from the site setting

add styles with dropdown choices for
- buttons
  - default, inner glow,
- rounded corners
  - default, none, larger, largest

In the styles tab, add a new section for Button Styles, with the following checkboxes
- Lighter backgrounds on default buttons (where the btn-default elements get a lighter default background color)
- Gradient effect on primary buttons
- Rounder buttons

Generate the right snippets for each.

:root {
//   --space: 0.25rem;
//   --d-border-radius: 4px;
//   --d-border-radius-large: 8px;
//   --d-input-border-radius: 4px;
//   --d-button-border-radius: 4px;
//   --d-nav-pill-border-radius: 4px;
//   --d-tag-border-radius: 3px;
  --d-sidebar-section-border-color: transparent;
  --d-sidebar-border-color: transparent;
  --d-sidebar-link-icon-color: var(--d-button-default-icon-color);
  --d-sidebar-header-icon-color: var(--d-button-default-icon-color);
  --d-sidebar-highlight-color: var(--d-button-primary-text-color);
  --d-button-default-bg-color: var(--tertiary-50);
  --d-button-default-bg-color--hover: var(--tertiary);
})

.d-header {
  backdrop-filter: blur(5px);
  background-color: rgb(var(--header_background-rgb), 0.8);
}