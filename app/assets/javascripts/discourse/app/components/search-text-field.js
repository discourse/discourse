import discourseComputed from "discourse-common/utils/decorators";
import { on } from "discourse-common/utils/decorators";
import TextField from "discourse/components/text-field";
import { applySearchAutocomplete } from "discourse/lib/search";

export default TextField.extend({
  autocomplete: "discourse",

  @discourseComputed("searchService.searchContextEnabled")
  placeholder(searchContextEnabled) {
    return searchContextEnabled ? "" : I18n.t("search.full_page_title");
  },

  @on("didInsertElement")
  becomeFocused() {
    const $searchInput = $(this.element);
    applySearchAutocomplete($searchInput, this.siteSettings);

    if (!this.hasAutofocus) {
      return;
    }
    // iOS is crazy, without this we will not be
    // at the top of the page
    $(window).scrollTop(0);
    $searchInput.focus();
  }
});
