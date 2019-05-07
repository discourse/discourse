import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
import TextField from "discourse/components/text-field";
import { applySearchAutocomplete } from "discourse/lib/search";

export default TextField.extend({
  @computed("searchService.searchContextEnabled")
  placeholder(searchContextEnabled) {
    return searchContextEnabled ? "" : I18n.t("search.full_page_title");
  },

  @on("didInsertElement")
  becomeFocused() {
    const $searchInput = this.$();
    applySearchAutocomplete($searchInput, this.siteSettings);

    if (!this.get("hasAutofocus")) {
      return;
    }
    // iOS is crazy, without this we will not be
    // at the top of the page
    $(window).scrollTop(0);
    $searchInput.focus();
  }
});
