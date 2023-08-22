import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { focusSearchButton } from "discourse/components/search-menu";

export default class Types extends Component {
  @service search;

  get filteredResultTypes() {
    // return only topic result types
    if (this.args.topicResultsOnly) {
      return this.args.resultTypes.filter(
        (resultType) => resultType.type === "topic"
      );
    }

    // return all result types minus topics
    return this.args.resultTypes.filter(
      (resultType) => resultType.type !== "topic"
    );
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
