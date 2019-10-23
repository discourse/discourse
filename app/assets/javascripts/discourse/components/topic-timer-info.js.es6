import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";
import Category from "discourse/models/category";
import computed from "ember-addons/ember-computed-decorators";
import { REMINDER_TYPE } from "discourse/controllers/edit-topic-timer";

export default Component.extend(
  bufferedRender({
    classNames: ["topic-status-info"],
    _delayedRerender: null,

    rerenderTriggers: [
      "topicClosed",
      "statusType",
      "executeAt",
      "basedOnLastPost",
      "duration",
      "categoryId"
    ],

    @computed("statusType")
    canRemoveTimer(type) {
      if (type === REMINDER_TYPE) return true;
      return this.currentUser && this.currentUser.get("canManageTopic");
    },

    buildBuffer(buffer) {
      if (!this.executeAt) return;

      const topicStatus = this.topicClosed ? "close" : "open";
      const topicStatusKnown = this.topicClosed !== undefined;
      if (topicStatusKnown && topicStatus === this.statusType) return;

      const statusUpdateAt = moment(this.executeAt);
      const duration = moment.duration(statusUpdateAt - moment());
      const minutesLeft = duration.asMinutes();

      if (minutesLeft > 0) {
        let rerenderDelay = 1000;
        if (minutesLeft > 2160) {
          rerenderDelay = 12 * 60 * 60000;
        } else if (minutesLeft > 1410) {
          rerenderDelay = 60 * 60000;
        } else if (minutesLeft > 90) {
          rerenderDelay = 30 * 60000;
        } else if (minutesLeft > 2) {
          rerenderDelay = 60000;
        }
        let autoCloseHours = this.duration || 0;

        buffer.push(`<h3 class="topic-timer-heading">`);

        let options = {
          timeLeft: duration.humanize(true),
          duration: moment.duration(autoCloseHours, "hours").humanize()
        };

        const categoryId = this.categoryId;
        if (categoryId) {
          const category = Category.findById(categoryId);

          options = Object.assign(
            {
              categoryName: category.get("slug"),
              categoryUrl: category.get("url")
            },
            options
          );
        }

        buffer.push(
          `<span title="${moment(this.executeAt).format("LLLL")}">${iconHTML(
            "far-clock"
          )} ${I18n.t(this._noticeKey(), options)}</span>`
        );
        if (this.removeTopicTimer && this.canRemoveTimer) {
          buffer.push(
            `<button class="btn topic-timer-remove no-text" title="${I18n.t(
              "post.controls.remove_timer"
            )}">${iconHTML("trash-alt")}</button>`
          );
        }
        buffer.push("</h3>");

        // TODO Sam: concerned this can cause a heavy rerender loop
        if (!Ember.testing) {
          this._delayedRerender = Ember.run.later(
            this,
            this.rerender,
            rerenderDelay
          );
        }
      }
    },

    didInsertElement() {
      this._super(...arguments);

      if (this.removeTopicTimer) {
        $(this.element).on(
          "click.topic-timer-remove",
          "button",
          this.removeTopicTimer
        );
      }
    },

    willDestroyElement() {
      $(this.element).off("click.topic-timer-remove", this.removeTopicTimer);

      if (this._delayedRerender) {
        Ember.run.cancel(this._delayedRerender);
      }
    },

    _noticeKey() {
      const statusType = this.statusType;

      if (this.basedOnLastPost) {
        return `topic.status_update_notice.auto_${statusType}_based_on_last_post`;
      } else {
        return `topic.status_update_notice.auto_${statusType}`;
      }
    }
  })
);
