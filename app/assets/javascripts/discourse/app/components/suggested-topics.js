import Component from "@glimmer/component";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";

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

  @computed("moreTopicsPreferenceTracking.selectedTab")
  get hidden() {
    return this.moreTopicsPreferenceTracking.selectedTab !== this.listId;
  }

  @action
  registerList() {
    this.moreTopicsPreferenceTracking.registerTopicList({
      name: I18n.t("suggested_topics.pill"),
      id: this.listId,
    });
  }

  @action
  removeList() {
    this.moreTopicsPreferenceTracking.removeTopicList(this.listId);
  }
}
