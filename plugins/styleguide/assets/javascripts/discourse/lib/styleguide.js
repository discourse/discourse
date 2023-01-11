import DiscourseTemplateMap from "discourse-common/lib/discourse-template-map";
let _allCategories = null;
let _sectionsById = {};
let _notes = {};

export const CATEGORIES = ["atoms", "molecules", "organisms"];

export function sectionById(id) {
  // prime cache
  allCategories();

  return _sectionsById[id];
}

function sortSections(a, b) {
  let result = a.priority - b.priority;
  if (result === 0) {
    return a.id < b.id ? -1 : 1;
  }
  return result;
}

export function allCategories() {
  if (_allCategories) {
    return _allCategories;
  }

  let categories = {};

  let paths = CATEGORIES.join("|");

  // Find a list of sections based on what templates are available
  // eslint-disable-next-line no-undef
  DiscourseTemplateMap.keys().forEach((e) => {
    let regexp = new RegExp(`styleguide\/(${paths})\/(\\d+)?\\-?([^\\/]+)$`);
    let matches = e.match(regexp);
    if (matches) {
      let section = {
        id: matches[3],
        priority: parseInt(matches[2] || "100", 10),
        category: matches[1],
        templateName: e.replace(/^.*styleguide\//, ""),
      };
      if (!categories[section.category]) {
        categories[section.category] = [];
      }
      categories[section.category].push(section);
      _sectionsById[section.id] = section;
    }

    // Look for notes
    regexp = new RegExp(`components\/notes\/(\\d+)?\\-?([^\\/]+)$`);
    matches = e.match(regexp);
    if (matches) {
      _notes[matches[2]] = e.replace(/^.*notes\//, "");
    }
  });

  _allCategories = [];
  CATEGORIES.forEach((c) => {
    let sections = categories[c];
    if (sections) {
      _allCategories.push({
        id: c,
        sections: sections.sort(sortSections),
      });
    }
  });
  return _allCategories;
}

export function findNote(section) {
  return _notes[section.id];
}
