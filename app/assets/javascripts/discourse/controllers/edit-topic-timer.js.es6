import { default as computed } from "ember-addons/ember-computed-decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import TopicTimer from "discourse/models/topic-timer";
import { popupAjaxError } from "discourse/lib/ajax-error";

export const CLOSE_STATUS_TYPE = "close";
export const OPEN_STATUS_TYPE = "open";
export const PUBLISH_TO_CATEGORY_STATUS_TYPE = "publish_to_category";
export const DELETE_STATUS_TYPE = "delete";
export const REMINDER_TYPE = "reminder";
export const BUMP_TYPE = "bump";

export default Ember.Controller.extend(ModalFunctionality, {
  loading: false,
  isPublic: "true",

  @computed("model.closed")
  publicTimerTypes(closed) {
    let types = [
      {
        id: CLOSE_STATUS_TYPE,
        name: I18n.t(
          closed ? "topic.temp_open.title" : "topic.auto_close.title"
        )
      },
      {
        id: OPEN_STATUS_TYPE,
        name: I18n.t(
          closed ? "topic.auto_reopen.title" : "topic.temp_close.title"
        )
      },
      {
        id: PUBLISH_TO_CATEGORY_STATUS_TYPE,
        name: I18n.t("topic.publish_to_category.title")
      },
      {
        id: BUMP_TYPE,
        name: I18n.t("topic.auto_bump.title")
      }
    ];
    if (this.currentUser.get("staff")) {
      types.push({
        id: DELETE_STATUS_TYPE,
        name: I18n.t("topic.auto_delete.title")
      });
    }
    return types;
  },

  @computed()
  privateTimerTypes() {
    return [{ id: REMINDER_TYPE, name: I18n.t("topic.reminder.title") }];
  },

  @computed("isPublic", "publicTimerTypes", "privateTimerTypes")
  selections(isPublic, publicTimerTypes, privateTimerTypes) {
    return "true" === isPublic ? publicTimerTypes : privateTimerTypes;
  },

  @computed("isPublic", "model.topic_timer", "model.private_topic_timer")
  topicTimer(isPublic, publicTopicTimer, privateTopicTimer) {
    return "true" === isPublic ? publicTopicTimer : privateTopicTimer;
  },

  _setTimer(time, statusType) {
    this.set("loading", true);

    TopicTimer.updateStatus(
      this.get("model.id"),
      time,
      this.get("topicTimer.based_on_last_post"),
      statusType,
      this.get("topicTimer.category_id")
    )
      .then(result => {
        if (time) {
          this.send("closeModal");

          Ember.setProperties(this.get("topicTimer"), {
            execute_at: result.execute_at,
            duration: result.duration,
            category_id: result.category_id
          });

          this.set("model.closed", result.closed);
        } else {
          const topicTimer =
            this.get("isPublic") === "true"
              ? "topic_timer"
              : "private_topic_timer";
          this.set(`model.${topicTimer}`, Ember.Object.create({}));

          this.setProperties({
            selection: null
          });
        }
      })
      .catch(error => {
        popupAjaxError(error);
      })
      .finally(() => this.set("loading", false));
  },

  actions: {
    saveTimer() {
      this._setTimer(
        this.get("topicTimer.updateTime"),
        this.get("topicTimer.status_type")
      );
    },

    removeTimer() {
      this._setTimer(null, this.get("topicTimer.status_type"));
    }
  }
});
