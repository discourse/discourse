import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend({
  elementId: "related-messages",
  classNames: ["suggested-topics"],

  @computed("topic")
  relatedTitle(topic) {
    const href = this.currentUser && this.currentUser.pmPath(topic);
    return href
      ? `<a href="${href}">${iconHTML("envelope", {
          class: "private-message-glyph"
        })}</a><span>${I18n.t("related_messages.title")}</span>`
      : I18n.t("related_messages.title");
  }
});
