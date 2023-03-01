import Component from "@glimmer/component";
import discourseDebounce from "discourse-common/lib/debounce";
import { action } from "@ember/object";

export default class SearchTerm extends Component {
  @action
  updateSearchTerm(input) {
    // utilze discourseDebounce as @debounce does not work for native class syntax
    discourseDebounce(
      this,
      this.parseAndUpdateSearchTerm,
      this.args.value,
      input,
      200
    );
  }

  parseAndUpdateSearchTerm(originalVal, newVal) {
    // remove zero-width chars
    const parsedVal = newVal.target.value.replace(/[\u200B-\u200D\uFEFF]/, "");

    if (parsedVal !== originalVal) {
      this.args.searchTermChanged(parsedVal);
    }
  }
}
