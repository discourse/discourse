import Component from "@ember/component";
import I18n from "I18n";
import { action } from "@ember/object";
import { getOwner } from "discourse-common/lib/get-owner";
import { or } from "@ember/object/computed";

export default Component.extend({
  tagName: "",

  init() {
    this._super(...arguments);

    this.loadLocalDates();
  },

  get postLocalDateFormatted() {
    return this.postLocalDate().format(I18n.t("dates.long_no_year"));
  },

  showPostLocalDate: or("postDetectedLocalDate", "postDetectedLocalTime"),

  loadLocalDates() {
    let postEl = document.querySelector(`[data-post-id="${this.postId}"]`);
    let localDateEl = null;
    if (postEl) {
      localDateEl = postEl.querySelector(".discourse-local-date");
    }

    this.setProperties({
      postDetectedLocalDate: localDateEl ? localDateEl.dataset.date : null,
      postDetectedLocalTime: localDateEl ? localDateEl.dataset.time : null,
      postDetectedLocalTimezone: localDateEl
        ? localDateEl.dataset.timezone
        : null,
    });
  },

  postLocalDate() {
    const bookmarkController = getOwner(this).lookup("controller:bookmark");
    let parsedPostLocalDate = bookmarkController._parseCustomDateTime(
      this.postDetectedLocalDate,
      this.postDetectedLocalTime,
      this.postDetectedLocalTimezone
    );

    if (!this.postDetectedLocalTime) {
      return bookmarkController.startOfDay(parsedPostLocalDate);
    }

    return parsedPostLocalDate;
  },

  @action
  setReminder() {
    return this.onChange(this.postLocalDate());
  },
});
