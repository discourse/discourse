import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class MoreLink extends Component {
  @service search;

  get topicResults() {
    const topicResults = this.args.resultTypes.filter(
      (resultType) => resultType.type === "topic"
    );
    return topicResults[0];
  }

  get moreUrl() {
    return this.topicResults.moreUrl();
  }

  @action
  moreOfType(type) {
    this.args.updateTypeFilter(type);
    this.args.triggerSearch();
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
