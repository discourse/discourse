import Controller, { inject as controller } from "@ember/controller";
import FilterModeMixin from "discourse/mixins/filter-mode";
import { action } from "@ember/object";
import I18n from "I18n";
import bootbox from "bootbox";

export default Controller.extend(FilterModeMixin, {
  discovery: controller(),

  showInfo: false,

  @action
  toggleInfo() {
    this.toggleProperty("showInfo");
  },

  @action
  deleteTag(tagInfo) {
    const numTopics =
      this.get("list.topic_list.tags.firstObject.topic_count") || 0;

    let confirmText =
      numTopics === 0
        ? I18n.t("tagging.delete_confirm_no_topics")
        : I18n.t("tagging.delete_confirm", { count: numTopics });

    if (tagInfo.synonyms.length > 0) {
      confirmText +=
        " " +
        I18n.t("tagging.delete_confirm_synonyms", {
          count: tagInfo.synonyms.length,
        });
    }

    bootbox.confirm(confirmText, (result) => {
      if (!result) {
        return;
      }

      this.tag
        .destroyRecord()
        .then(() => this.transitionToRoute("tags.index"))
        .catch(() => bootbox.alert(I18n.t("generic_error")));
    });
  },

  @action
  changeTagNotificationLevel(notificationLevel) {
    this.tagNotification
      .update({ notification_level: notificationLevel })
      .then((response) => {
        this.currentUser.set(
          "muted_tag_ids",
          this.currentUser.calculateMutedIds(
            notificationLevel,
            response.responseJson.tag_id,
            "muted_tag_ids"
          )
        );
      });
  },
});
