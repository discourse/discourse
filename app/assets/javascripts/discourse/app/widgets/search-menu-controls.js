import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";

createWidget("search-term", {
  tagName: "input",
  buildId: () => "search-term",
  buildKey: () => "search-term",

  buildAttributes(attrs) {
    return {
      type: "text",
      value: attrs.value || "",
      autocomplete: "off",
      placeholder: I18n.t("search.title"),
      "aria-label": I18n.t("search.title"),
    };
  },

  input(e) {
    const val = this.attrs.value;

    // remove zero-width chars
    const newVal = e.target.value.replace(/[\u200B-\u200D\uFEFF]/, "");

    if (newVal !== val) {
      this.sendWidgetAction("searchTermChanged", newVal);
    }
  },
});

// TODO: No longer used, remove in December 2021
createWidget("search-context", {
  html() {
    return false;
  },
});
