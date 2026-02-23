const STYLE_SNIPPETS = [
  {
    id: "sidebar-active-hover",
    group: "layout",
    css: [
      "--d-sidebar-link-icon-color: var(--d-button-default-icon-color);",
      "--d-sidebar-header-icon-color: var(--d-button-default-icon-color);",
      "--d-sidebar-highlight-color: var(--d-button-primary-text-color);",
      "--d-sidebar-highlight-hover-icon: var(--d-button-primary-text-color);",
      "--category-badge-hover-text-color: var(--d-button-primary-text-color);",
      "--d-menu-button--hover: var(--d-button-primary-text-color);",
      "--notifications-tracking-desc__hover: var(--d-button-primary-text-color);",
    ],
  },
  {
    id: "borderless-header-sidebar",
    group: "layout",
    css: [
      "--d-sidebar-section-border-color: transparent;",
      "--d-sidebar-border-color: transparent;",
    ],
    colorDefinitionsCss: ["--shadow-header: none;"],
  },
  {
    id: "glass-effect-header",
    group: "layout",
    rawCss: `.d-header {
  backdrop-filter: blur(5px);
  background-color: rgb(var(--header_background-rgb), 0.8);
}`,
  },
  {
    id: "lighter-default-buttons",
    group: "buttons",
    css: [
      "--d-button-default-bg-color: transparent;",
      "--d-button-default-border: 1px solid var(--primary-low-mid);",
    ],
  },
  {
    id: "gradient-primary-buttons",
    group: "buttons",
    rawCss: `.btn-primary:not(.btn-flat) {
  background-image: linear-gradient(0deg, var(--d-button-primary-bg-color), var(--tertiary-medium));
}`,
  },
  {
    id: "rounder-buttons",
    group: "buttons",
    css: ["--d-button-border-radius: 12px;"],
  },
];

export default STYLE_SNIPPETS;
