const STYLE_SNIPPETS = [
  {
    id: "sidebar-active-hover",
    css: [
      "--d-sidebar-section-border-color: transparent;",
      "--d-sidebar-border-color: transparent;",
      "--d-sidebar-link-icon-color: var(--d-button-default-icon-color);",
      "--d-sidebar-header-icon-color: var(--d-button-default-icon-color);",
      "--d-sidebar-highlight-color: var(--d-button-primary-text-color);",
      "--d-sidebar-highlight-hover-icon: var(--d-button-primary-text-color);",
      "--category-badge-hover-text-color: var(--d-button-primary-text-color);",
    ],
  },
  {
    id: "borderless-header-sidebar",
    css: [
      "--d-sidebar-section-border-color: transparent;",
      "--d-sidebar-border-color: transparent;",
    ],
    colorDefinitionsCss: ["--shadow-header: none;"],
  },
  {
    id: "glass-effect-header",
    rawCss: `.d-header {
  backdrop-filter: blur(5px);
  background-color: rgb(var(--header_background-rgb), 0.8);
}`,
  },
];

export default STYLE_SNIPPETS;
