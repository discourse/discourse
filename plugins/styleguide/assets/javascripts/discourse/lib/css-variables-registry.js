const CSS_VARIABLES = [
  // Base Colors
  { name: "--primary", category: "Base Colors", type: "color" },
  { name: "--primary-very-low", category: "Base Colors", type: "color" },
  { name: "--primary-low", category: "Base Colors", type: "color" },
  { name: "--primary-low-mid", category: "Base Colors", type: "color" },
  { name: "--primary-medium", category: "Base Colors", type: "color" },
  { name: "--primary-high", category: "Base Colors", type: "color" },
  { name: "--primary-50", category: "Base Colors", type: "color" },
  { name: "--primary-100", category: "Base Colors", type: "color" },
  { name: "--primary-200", category: "Base Colors", type: "color" },
  { name: "--primary-300", category: "Base Colors", type: "color" },
  { name: "--primary-400", category: "Base Colors", type: "color" },
  { name: "--primary-500", category: "Base Colors", type: "color" },
  { name: "--primary-600", category: "Base Colors", type: "color" },
  { name: "--primary-700", category: "Base Colors", type: "color" },
  { name: "--primary-800", category: "Base Colors", type: "color" },
  { name: "--primary-900", category: "Base Colors", type: "color" },
  { name: "--secondary", category: "Base Colors", type: "color" },
  { name: "--secondary-low", category: "Base Colors", type: "color" },
  { name: "--secondary-medium", category: "Base Colors", type: "color" },
  { name: "--secondary-high", category: "Base Colors", type: "color" },
  { name: "--tertiary", category: "Base Colors", type: "color" },
  { name: "--tertiary-low", category: "Base Colors", type: "color" },
  { name: "--tertiary-medium", category: "Base Colors", type: "color" },
  { name: "--tertiary-high", category: "Base Colors", type: "color" },
  { name: "--quaternary", category: "Base Colors", type: "color" },
  { name: "--quaternary-low", category: "Base Colors", type: "color" },
  { name: "--highlight", category: "Base Colors", type: "color" },
  { name: "--highlight-bg", category: "Base Colors", type: "color" },
  { name: "--danger", category: "Base Colors", type: "color" },
  { name: "--danger-low", category: "Base Colors", type: "color" },
  { name: "--danger-low-mid", category: "Base Colors", type: "color" },
  { name: "--danger-medium", category: "Base Colors", type: "color" },
  { name: "--success", category: "Base Colors", type: "color" },
  { name: "--success-low", category: "Base Colors", type: "color" },
  { name: "--success-medium", category: "Base Colors", type: "color" },
  { name: "--love", category: "Base Colors", type: "color" },
  { name: "--love-low", category: "Base Colors", type: "color" },
  { name: "--header_background", category: "Base Colors", type: "color" },
  { name: "--header_primary", category: "Base Colors", type: "color" },

  // Semantic Colors
  { name: "--d-link-color", category: "Semantic Colors", type: "color" },
  { name: "--title-color", category: "Semantic Colors", type: "color" },
  { name: "--title-color--read", category: "Semantic Colors", type: "color" },
  { name: "--excerpt-color", category: "Semantic Colors", type: "color" },
  { name: "--metadata-color", category: "Semantic Colors", type: "color" },
  {
    name: "--content-border-color",
    category: "Semantic Colors",
    type: "color",
  },
  { name: "--input-border-color", category: "Semantic Colors", type: "color" },
  { name: "--table-border-color", category: "Semantic Colors", type: "color" },
  {
    name: "--mention-background-color",
    category: "Semantic Colors",
    type: "color",
  },
  {
    name: "--d-badge-card-background-color",
    category: "Semantic Colors",
    type: "color",
  },
  { name: "--d-selected", category: "Semantic Colors", type: "color" },
  { name: "--d-hover", category: "Semantic Colors", type: "color" },

  // Styling
  { name: "--space", category: "Styling", type: "size" },
  { name: "--space-half", category: "Styling", type: "size" },
  { name: "--space-1", category: "Styling", type: "size" },
  { name: "--space-2", category: "Styling", type: "size" },
  { name: "--space-3", category: "Styling", type: "size" },
  { name: "--space-4", category: "Styling", type: "size" },
  { name: "--space-5", category: "Styling", type: "size" },
  { name: "--space-6", category: "Styling", type: "size" },
  { name: "--space-7", category: "Styling", type: "size" },
  { name: "--space-8", category: "Styling", type: "size" },
  { name: "--space-9", category: "Styling", type: "size" },
  { name: "--space-10", category: "Styling", type: "size" },
  { name: "--space-11", category: "Styling", type: "size" },
  { name: "--space-12", category: "Styling", type: "size" },
  { name: "--d-border-radius", category: "Styling", type: "radius" },
  {
    name: "--d-border-radius-large",
    category: "Styling",
    type: "radius",
  },
  {
    name: "--d-nav-pill-border-radius",
    category: "Styling",
    type: "radius",
  },
  {
    name: "--d-input-border-radius",
    category: "Styling",
    type: "radius",
  },
  {
    name: "--d-button-border-radius",
    category: "Styling",
    type: "radius",
  },
];

export function getCssVariableCategories() {
  const categories = new Map();
  for (const variable of CSS_VARIABLES) {
    if (!categories.has(variable.category)) {
      categories.set(variable.category, []);
    }
    categories.get(variable.category).push(variable);
  }
  return categories;
}

export function getAllCssVariables() {
  return CSS_VARIABLES;
}

export default CSS_VARIABLES;
