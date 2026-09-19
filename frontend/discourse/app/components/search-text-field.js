import { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { on } from "@ember-decorators/object";
import { applySearchAutocomplete } from "discourse/lib/search";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class SearchTextField extends DTextField {
  autocomplete = "off";
  enterkeyhint = "search";
  autocapitalize = "none";
  autocorrect = "off";

  @computed("searchService.searchContextEnabled")
  get placeholder() {
    return this.searchService?.searchContextEnabled
      ? ""
      : i18n("search.full_page_title");
  }

  @on("didInsertElement")
  becomeFocused() {
    this._autocompleteModifiers = applySearchAutocomplete(
      this.element,
      this.siteSettings,
      getOwner(this)
    );

    if (!this.hasAutofocus) {
      return;
    }
    // iOS is crazy, without this we will not be
    // at the top of the page
    window.scrollTo(0, 0);
    this.element.focus();
  }

  @on("willDestroyElement")
  teardown() {
    this._autocompleteModifiers?.forEach((m) => m.cleanup());
  }
}
