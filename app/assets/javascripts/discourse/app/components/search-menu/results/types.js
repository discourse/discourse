import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { focusSearchButton } from "discourse/components/search-menu";

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
  onKeydown(e) {
    if (e.key === "Escape") {
      focusSearchButton();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    this.search.handleResultInsertion(e);
    this.search.handleArrowUpOrDown(e);
  }
}
