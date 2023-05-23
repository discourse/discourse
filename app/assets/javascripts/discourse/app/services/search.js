import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { computed } from "@ember/object";

export default class Search extends Service {
  @tracked activeGlobalSearchTerm = "";
  @tracked searchContext;

  // only relative for the widget search menu
  searchContextEnabled = false; // checkbox to scope search
  highlightTerm = null;

  get contextType() {
    return this.searchContext?.type || null;
  }

  @action
  updateActiveGlobalSearchTerm(term) {
    this.activeGlobalSearchTerm = term;
  }

  @action
  setSearchContext(value) {
    this.searchContext = value;
  }
}
