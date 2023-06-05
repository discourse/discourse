import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class Types extends Component {
  @service search;

  get filteredResultTypes() {
    if (this.args.topicResultsOnly) {
      return this.args.resultTypes.filter(
        (resultType) => resultType.type === "topic"
      );
    }
    return this.args.resultTypes;
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      document.querySelector("#search-button").focus();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    this.search.handleArrowUpOrDown(e);
  }
}
