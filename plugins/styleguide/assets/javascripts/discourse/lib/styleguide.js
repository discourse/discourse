let _allCategories = null;
let _sectionsById = {};
let _notes = {};

export const CATEGORIES = ["atoms", "molecules", "organisms"];

const SECTIONS = [
  "sections/atoms/00-typography",
  "sections/atoms/01-font-scale",
  "sections/atoms/02-buttons",
  "sections/atoms/03-colors",
  "sections/atoms/04-icons",
  "sections/atoms/05-input-fields",
  "sections/atoms/06-spinners",
  "sections/atoms/date-time-inputs",
  "sections/atoms/dropdowns",
  "sections/atoms/topic-link",
  "sections/atoms/topic-statuses",
  "sections/molecules/bread-crumbs",
  "sections/molecules/categories",
  "sections/molecules/char-counter",
  "sections/molecules/empty-state",
  "sections/molecules/footer-message",
  "sections/molecules/header-icons",
  "sections/molecules/navigation-bar",
  "sections/molecules/navigation-stacked",
  "sections/molecules/post-menu",
  "sections/molecules/rich-tooltip",
  "sections/molecules/signup-cta",
  "sections/molecules/topic-list-item",
  "sections/molecules/topic-notifications",
  "sections/molecules/topic-timer-info",
  "sections/organisms/00-post",
  "sections/organisms/01-topic-map",
  "sections/organisms/03-topic-footer-buttons",
  "sections/organisms/04-topic-list",
  "sections/organisms/basic-topic-list",
  "sections/organisms/categories-list",
  "sections/organisms/modal",
  "sections/organisms/navigation",
  "sections/organisms/site-header",
  "sections/organisms/suggested-topics",
  "sections/organisms/user-about",
];

export function addSection(componentName) {
  if (!SECTIONS.includes(componentName)) {
    SECTIONS.push(componentName);
  }
}

export function sectionById(id) {
  // prime cache
  allCategories();

  return _sectionsById[id];
}

function sortSections(a, b) {
  const result = a.priority - b.priority;

  if (result !== 0) {
    return result;
  }

  return a.id < b.id ? -1 : 1;
}

export function allCategories() {
  if (_allCategories) {
    return _allCategories;
  }

  const categories = {};
  const paths = CATEGORIES.join("|");
  const regexp = new RegExp(`[/]?(${paths})\/(\\d+)?\\-?([^\\/]+)$`);

  for (const componentName of SECTIONS) {
    const match = componentName.match(regexp);

    if (match) {
      const [, category, priority, id] = match;
      const section = {
        id,
        priority: parseInt(priority || "100", 10),
        category,
        componentName,
      };

      categories[section.category] ||= [];
      categories[section.category].push(section);

      _sectionsById[section.id] = section;
    }

    // Look for notes
    const notesRegexp = new RegExp(`[/]?notes\/(\\d+)?\\-?([^\\/]+)$`);
    const notesMatch = componentName.match(notesRegexp);
    if (notesMatch) {
      _notes[notesMatch[2]] = componentName.replace(/^.*notes\//, "");
    }
  }

  _allCategories = [];
  for (const category of CATEGORIES) {
    const sections = categories[category];

    if (sections) {
      _allCategories.push({
        id: category,
        sections: sections.sort(sortSections),
      });
    }
  }

  return _allCategories;
}

export function findNote(section) {
  return _notes[section.id];
}
