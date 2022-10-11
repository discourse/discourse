import { findRawTemplate } from "discourse-common/lib/raw-templates";

// TODO: (martin) Make a more generic version of these functions.
import { categoryHashtagTriggerRule } from "discourse/lib/category-hashtags";
import { search as searchCategoryTag } from "discourse/lib/category-tag-search";

export function setupHashtagAutocomplete(
  $textArea,
  siteSettings,
  afterComplete
) {
  if (siteSettings.enable_experimental_hashtag_autocomplete) {
    _setupExperimental($textArea, siteSettings, afterComplete);
  } else {
    _setup($textArea, siteSettings, afterComplete);
  }
}

function _setupExperimental($textArea, siteSettings, afterComplete) {
  $textArea.autocomplete({
    template: findRawTemplate("hashtag-autocomplete"),
    key: "#",
    afterComplete,
    treatAsTextarea: $textArea[0].tagName === "INPUT",
    transformComplete: (obj) => {
      return obj.text;
    },
    dataSource: (term) => {
      if (term.match(/\s/)) {
        return null;
      }
      return searchCategoryTag(term, siteSettings);
    },
    triggerRule: (textarea, opts) => {
      return categoryHashtagTriggerRule(textarea, opts);
    },
  });
}

function _setup($textArea, siteSettings, afterComplete) {
  $textArea.autocomplete({
    template: findRawTemplate("category-tag-autocomplete"),
    key: "#",
    afterComplete,
    transformComplete: (obj) => {
      return obj.text;
    },
    dataSource: (term) => {
      if (term.match(/\s/)) {
        return null;
      }
      return searchCategoryTag(term, siteSettings);
    },
    triggerRule: (textarea, opts) => {
      return categoryHashtagTriggerRule(textarea, opts);
    },
  });
}
