import Component from "@glimmer/component";
import { computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default class SuggestedTopics extends Component {
  @service moreTopicsPreferenceTracking;
  @service currentUser;

  listId = "suggested-topics";

  get suggestedTitleLabel() {
    const href = this.currentUser && this.currentUser.pmPath(this.args.topic);
    if (this.args.topic.isPrivateMessage && href) {
      return "suggested_topics.pm_title";
    } else {
      return "suggested_topics.title";
    }
  }

  @computed("moreTopicsPreferenceTracking.preference")
  get hidden() {
    return this.moreTopicsPreferenceTracking.preference !== this.listId;
  }
}
