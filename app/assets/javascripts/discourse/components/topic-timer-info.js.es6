import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";
import Category from "discourse/models/category";

export default Ember.Component.extend(
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

    buildBuffer(buffer) {
      if (!this.executeAt) return;

      const topicStatus = this.topicClosed ? "close" : "open";
      const topicStatusKnown = this.topicClosed !== undefined;
      if (topicStatusKnown && topicStatus === this.statusType) return;

      let statusUpdateAt = moment(this.executeAt);

      let duration = moment.duration(statusUpdateAt - moment());
      let minutesLeft = duration.asMinutes();
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

      buffer.push(`<h3>${iconHTML("far-clock")} `);

      let options = {
        timeLeft: duration.humanize(true),
        duration: moment.duration(autoCloseHours, "hours").humanize()
      };

      const categoryId = this.categoryId;

      if (categoryId) {
        const category = Category.findById(categoryId);

        options = Object.assign(
          {
            categoryName: category.slug,
            categoryUrl: category.url
          },
          options
        );
      }

      buffer.push(
        `<span title="${moment(this.executeAt).format("LLLL")}">${I18n.t(
          this._noticeKey(),
          options
        )}</span>`
      );
      buffer.push("</h3>");

      // TODO Sam: concerned this can cause a heavy rerender loop
      if (!Ember.testing) {
        this._delayedRerender = Ember.run.later(
          this,
          this.rerender,
          rerenderDelay
        );
      }
    },

    willDestroyElement() {
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
