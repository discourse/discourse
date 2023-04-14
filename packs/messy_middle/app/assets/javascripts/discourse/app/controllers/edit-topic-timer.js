import EmberObject, { setProperties } from "@ember/object";
import Controller from "@ember/controller";
import { FORMAT } from "select-kit/components/future-date-input-selector";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import TopicTimer from "discourse/models/topic-timer";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export const CLOSE_STATUS_TYPE = "close";
export const CLOSE_AFTER_LAST_POST_STATUS_TYPE = "close_after_last_post";
export const OPEN_STATUS_TYPE = "open";
export const PUBLISH_TO_CATEGORY_STATUS_TYPE = "publish_to_category";
export const DELETE_STATUS_TYPE = "delete";
export const BUMP_TYPE = "bump";
export const DELETE_REPLIES_TYPE = "delete_replies";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  isPublic: "true",

  @discourseComputed(
    "model.closed",
    "model.category",
    "model.isPrivateMessage",
    "model.invisible"
  )
  publicTimerTypes(closed, category, isPrivateMessage, invisible) {
    let types = [];

    if (!closed) {
      types.push({
        id: CLOSE_STATUS_TYPE,
        name: I18n.t("topic.auto_close.title"),
      });
      types.push({
        id: CLOSE_AFTER_LAST_POST_STATUS_TYPE,
        name: I18n.t("topic.auto_close_after_last_post.title"),
      });
    }

    if (closed) {
      types.push({
        id: OPEN_STATUS_TYPE,
        name: I18n.t("topic.auto_reopen.title"),
      });
    }

    if (this.model.details.can_delete) {
      types.push({
        id: DELETE_STATUS_TYPE,
        name: I18n.t("topic.auto_delete.title"),
      });
    }

    types.push({
      id: BUMP_TYPE,
      name: I18n.t("topic.auto_bump.title"),
    });

    if (this.model.details.can_delete) {
      types.push({
        id: DELETE_REPLIES_TYPE,
        name: I18n.t("topic.auto_delete_replies.title"),
      });
    }

    if (closed) {
      types.push({
        id: CLOSE_STATUS_TYPE,
        name: I18n.t("topic.temp_open.title"),
      });
    }

    if (!closed) {
      types.push({
        id: OPEN_STATUS_TYPE,
        name: I18n.t("topic.temp_close.title"),
      });
    }

    if (
      (category && category.read_restricted) ||
      isPrivateMessage ||
      invisible
    ) {
      types.push({
        id: PUBLISH_TO_CATEGORY_STATUS_TYPE,
        name: I18n.t("topic.publish_to_category.title"),
      });
    }

    return types;
  },

  topicTimer: alias("model.topic_timer"),

  _setTimer(time, durationMinutes, statusType, basedOnLastPost, categoryId) {
    this.set("loading", true);

    TopicTimer.update(
      this.get("model.id"),
      time,
      basedOnLastPost,
      statusType,
      categoryId,
      durationMinutes
    )
      .then((result) => {
        if (time || durationMinutes) {
          this.send("closeModal");

          setProperties(this.topicTimer, {
            execute_at: result.execute_at,
            duration_minutes: result.duration_minutes,
            category_id: result.category_id,
          });

          this.set("model.closed", result.closed);
        } else {
          this.set(
            "model.topic_timer",
            EmberObject.create({ status_type: this.defaultStatusType })
          );

          this.send("onChangeInput", null, null);
        }
      })
      .catch(popupAjaxError)
      .finally(() => this.set("loading", false));
  },

  onShow() {
    let time = null;
    const executeAt = this.get("topicTimer.execute_at");

    if (executeAt) {
      const closeTime = moment(executeAt);

      if (closeTime > moment()) {
        time = closeTime.format(FORMAT);
      }
    }

    this.send("onChangeInput", null, time);

    if (!this.get("topicTimer.status_type")) {
      this.send("onChangeStatusType", this.defaultStatusType);
    }

    if (
      this.get("topicTimer.status_type") === CLOSE_STATUS_TYPE &&
      this.get("topicTimer.based_on_last_post")
    ) {
      this.send("onChangeStatusType", CLOSE_AFTER_LAST_POST_STATUS_TYPE);
    }
  },

  @discourseComputed("publicTimerTypes")
  defaultStatusType(publicTimerTypes) {
    return publicTimerTypes[0].id;
  },

  actions: {
    onChangeStatusType(value) {
      this.setProperties({
        "topicTimer.based_on_last_post":
          CLOSE_AFTER_LAST_POST_STATUS_TYPE === value,
        "topicTimer.status_type": value,
      });
    },

    onChangeInput(_type, time) {
      if (moment.isMoment(time)) {
        time = time.format(FORMAT);
      }
      this.set("topicTimer.updateTime", time);
    },

    saveTimer() {
      if (
        !this.get("topicTimer.updateTime") &&
        !this.get("topicTimer.duration_minutes")
      ) {
        this.flash(
          I18n.t("topic.topic_status_update.time_frame_required"),
          "error"
        );
        return;
      }

      if (
        this.get("topicTimer.duration_minutes") &&
        !this.get("topicTimer.updateTime")
      ) {
        if (this.get("topicTimer.duration_minutes") <= 0) {
          this.flash(I18n.t("topic.topic_status_update.min_duration"), "error");
          return;
        }

        // cannot be more than 20 years
        if (this.get("topicTimer.duration_minutes") > 20 * 365 * 1440) {
          this.flash(I18n.t("topic.topic_status_update.max_duration"), "error");
          return;
        }
      }

      let statusType = this.get("topicTimer.status_type");
      if (statusType === CLOSE_AFTER_LAST_POST_STATUS_TYPE) {
        statusType = CLOSE_STATUS_TYPE;
      }

      this._setTimer(
        this.get("topicTimer.updateTime"),
        this.get("topicTimer.duration_minutes"),
        statusType,
        this.get("topicTimer.based_on_last_post"),
        this.get("topicTimer.category_id")
      );
    },

    removeTimer() {
      let statusType = this.get("topicTimer.status_type");
      if (statusType === CLOSE_AFTER_LAST_POST_STATUS_TYPE) {
        statusType = CLOSE_STATUS_TYPE;
      }
      this._setTimer(null, null, statusType);
    },
  },
});
