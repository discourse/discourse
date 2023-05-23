import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class Search extends Service {
  @tracked activeGlobalSearchTerm = "";

  @action
  updateActiveGlobalSearchTerm(term) {
    this.activeGlobalSearchTerm = term;
  }

  //searchContextEnabled = false; // checkbox to scope search
  //searchContext = null;
  //highlightTerm = null;

  //@discourseComputed("searchContext")
  //contextType: {
  //get(searchContext) {
  //return searchContext?.type;
  //}

  //set(value, searchContext) {
  //this.set("searchContext", { ...searchContext, type: value });
  //return value;
  //}
  //}
}
