import Component from "@ember/component";
import { cancel, next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import { DELETE_REPLIES_TYPE } from "discourse/components/modal/edit-topic-timer";
import discourseComputed from "discourse/lib/decorators";
import { iconHTML } from "discourse/lib/icon-library";
import discourseLater from "discourse/lib/later";
import Category from "discourse/models/category";
import { isTesting } from "discourse-common/config/environment";
import { i18n } from "discourse-i18n";

@classNames("topic-timer-info")
export default class TopicTimerInfo extends Component {
  clockIcon = htmlSafe(`${iconHTML("far-clock")}`);
  trashLabel = i18n("post.controls.remove_timer");

  title = null;
  notice = null;
  showTopicTimer = null;
  showTopicTimerModal = null;
  removeTopicTimer = null;
  _delayedRerender = null;

  @on("didReceiveAttrs")
  setupRenderer() {
    this.renderTopicTimer();
  }

  @on("willDestroyElement")
  cancelDelayedRenderer() {
    if (this._delayedRerender) {
      cancel(this._delayedRerender);
    }
  }

  @discourseComputed
  canModifyTimer() {
    return this.currentUser && this.currentUser.get("canManageTopic");
  }

  @discourseComputed("canModifyTimer", "removeTopicTimer")
  showTrashCan(canModifyTimer, removeTopicTimer) {
    return canModifyTimer && removeTopicTimer;
  }

  @discourseComputed("canModifyTimer", "showTopicTimerModal")
  showEdit(canModifyTimer, showTopicTimerModal) {
    return canModifyTimer && showTopicTimerModal;
  }

  additionalOpts() {
    return {};
  }

  renderTopicTimer() {
    const isDeleteRepliesType = this.statusType === DELETE_REPLIES_TYPE;

    if (
      !isDeleteRepliesType &&
      !this.basedOnLastPost &&
      (!this.executeAt || this.executeAt < moment())
    ) {
      this.set("showTopicTimer", null);
      return;
    }

    if (this.isDestroyed) {
      return;
    }

    const topicStatus = this.topicClosed ? "close" : "open";
    const topicStatusKnown = this.topicClosed !== undefined;
    const topicStatusUpdate = this.statusUpdate !== undefined;
    if (topicStatusKnown && topicStatus === this.statusType) {
      if (!topicStatusUpdate) {
        return;
      }

      // The topic status has just been toggled, so we can hide the timer info.
      this.set("showTopicTimer", null);
      // The timer has already been removed on the back end. The front end is not aware of the change yet.
      // TODO: next() is a hack, to-be-removed
      next(() => this.set("executeAt", null));
      return;
    }

    const statusUpdateAt = moment(this.executeAt);
    const duration = moment.duration(statusUpdateAt - moment());
    const minutesLeft = duration.asMinutes();
    if (minutesLeft > 0 || isDeleteRepliesType || this.basedOnLastPost) {
      // We don't want to display a notice before a topic timer time has been set
      if (!this.executeAt) {
        return;
      }

      let durationMinutes = parseInt(this.durationMinutes, 10) || 0;

      let options = {
        timeLeft: duration.humanize(true),
        duration: moment
          .duration(durationMinutes, "minutes")
          .humanize({ s: 60, m: 60, h: 24 }),
      };

      const categoryId = this.categoryId;
      if (categoryId) {
        const category = Category.findById(categoryId);

        options = Object.assign(
          {
            categoryName: category.get("slug"),
            categoryUrl: category.get("url"),
          },
          options
        );
      }

      options = Object.assign(options, this.additionalOpts());
      this.setProperties({
        title: htmlSafe(`${moment(this.executeAt).format("LLLL")}`),
        notice: htmlSafe(`${i18n(this._noticeKey(), options)}`),
        showTopicTimer: true,
      });

      // TODO Sam: concerned this can cause a heavy rerender loop
      if (!isTesting()) {
        this._delayedRerender = discourseLater(() => {
          this.renderTopicTimer();
        }, this.rerenderDelay(minutesLeft));
      }
    } else {
      this.set("showTopicTimer", null);
    }
  }

  rerenderDelay(minutesLeft) {
    if (minutesLeft > 2160) {
      return 12 * 60 * 60000;
    } else if (minutesLeft > 1410) {
      return 60 * 60000;
    } else if (minutesLeft > 90) {
      return 30 * 60000;
    } else if (minutesLeft > 2) {
      return 60000;
    }

    return 1000;
  }

  _noticeKey() {
    let statusType = this.statusType;
    if (statusType === "silent_close") {
      statusType = "close";
    }
    if (this.basedOnLastPost && statusType === "close") {
      statusType = "close_after_last_post";
    }

    return `topic.status_update_notice.auto_${statusType}`;
  }
}
