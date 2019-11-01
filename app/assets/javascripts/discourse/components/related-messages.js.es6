import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  elementId: "related-messages",
  classNames: ["suggested-topics"],

  @computed("topic")
  targetUser(topic) {
    if (!topic || !topic.isPrivateMessage) {
      return;
    }
    const allowedUsers = topic.details.allowed_users;
    if (
      topic.relatedMessages &&
      topic.relatedMessages.length >= 5 &&
      allowedUsers.length === 2 &&
      topic.details.allowed_groups.length === 0 &&
      allowedUsers.find(u => u.username === this.currentUser.username)
    ) {
      return allowedUsers.find(u => u.username !== this.currentUser.username);
    }
  },

  @computed
  searchLink() {
    return Discourse.getURL(
      `/search?expanded=true&q=%40${this.targetUser.username}%20in%3Apersonal-direct`
    );
  },

  @computed("topic")
  relatedTitle(topic) {
    const href = this.currentUser && this.currentUser.pmPath(topic);
    return href
      ? `<a href="${href}" aria-label="${I18n.t(
          "user.messages.inbox"
        )}">${iconHTML("envelope", {
          class: "private-message-glyph"
        })}</a><span>${I18n.t("related_messages.title")}</span>`
      : I18n.t("related_messages.title");
  }
});
