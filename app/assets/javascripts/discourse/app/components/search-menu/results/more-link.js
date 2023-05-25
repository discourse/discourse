import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class MoreLink extends Component {
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
}
