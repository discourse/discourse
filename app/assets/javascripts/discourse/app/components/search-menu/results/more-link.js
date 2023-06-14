import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { focusSearchButton } from "discourse/components/search-menu";

export default class MoreLink extends Component {
  @service search;

  get topicResults() {
    const topicResults = this.args.resultTypes.filter(
      (resultType) => resultType.type === "topic"
    );
    return topicResults[0];
  }

  get moreUrl() {
    return this.topicResults.moreUrl && this.topicResults.moreUrl();
  }

  @action
  moreOfType(type) {
    this.args.updateTypeFilter(type);
    this.args.triggerSearch();
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      focusSearchButton();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    this.search.handleArrowUpOrDown(e);
  }
}
