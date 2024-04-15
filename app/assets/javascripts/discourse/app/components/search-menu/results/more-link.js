import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";

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
  transitionToMoreUrl(event) {
    event.preventDefault();
    this.args.closeSearchMenu();
    DiscourseURL.routeTo(this.moreUrl);
    return false;
  }

  @action
  moreOfType(type) {
    this.args.updateTypeFilter(type);
    this.args.triggerSearch();
    this.args.closeSearchMenu();
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    this.search.handleArrowUpOrDown(e);
  }
}
