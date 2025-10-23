import { getOwner } from "@ember/owner";
import { on } from "@ember-decorators/object";
import $ from "jquery";
import TextField from "discourse/components/text-field";
import discourseComputed from "discourse/lib/decorators";
import { applySearchAutocomplete } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class SearchTextField extends TextField {
  autocomplete = "off";
  enterkeyhint = "search";
  autocapitalize = "none";
  autocorrect = "off";

  @discourseComputed("searchService.searchContextEnabled")
  placeholder(searchContextEnabled) {
    return searchContextEnabled ? "" : i18n("search.full_page_title");
  }

  @on("didInsertElement")
  becomeFocused() {
    applySearchAutocomplete(this.element, this.siteSettings, getOwner(this));

    const $searchInput = $(this.element);
    if (!this.hasAutofocus) {
      return;
    }
    // iOS is crazy, without this we will not be
    // at the top of the page
    $(window).scrollTop(0);
    $searchInput.focus();
  }
}
