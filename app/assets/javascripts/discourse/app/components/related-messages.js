import Component from "@glimmer/component";
import { action, computed } from "@ember/object";
import getURL from "discourse-common/lib/get-url";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class RelatedMessages extends Component {
  @service moreTopicsPreferenceTracking;
  @service currentUser;

  listId = "related-Messages";

  @computed("moreTopicsPreferenceTracking.selectedTab")
  get hidden() {
    return this.moreTopicsPreferenceTracking.selectedTab !== this.listId;
  }

  @action
  registerList() {
    this.moreTopicsPreferenceTracking.registerTopicList({
      name: I18n.t("related_messages.pill"),
      id: this.listId,
    });
  }

  @action
  removeList() {
    this.moreTopicsPreferenceTracking.removeTopicList(this.listId);
  }

  get targetUser() {
    const topic = this.args.topic;

    if (!topic || !topic.isPrivateMessage) {
      return;
    }

    const allowedUsers = topic.details.allowed_users;

    if (
      topic.relatedMessages &&
      topic.relatedMessages.length >= 5 &&
      allowedUsers.length === 2 &&
      topic.details.allowed_groups.length === 0 &&
      allowedUsers.find((u) => u.username === this.currentUser.username)
    ) {
      return allowedUsers.find((u) => u.username !== this.currentUser.username);
    }
  }

  get searchLink() {
    return getURL(
      `/search?expanded=true&q=%40${this.targetUser.username}%20in%3Apersonal-direct`
    );
  }
}
