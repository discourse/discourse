import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";
import { Promise } from "rsvp";

const START_OF_DAY_HOUR = 8;
const REMINDER_TYPES = {
  AT_DESKTOP: "at-desktop",
  LATER_TODAY: "later-today",
  NEXT_BUSINESS_DAY: "next-business-day",
  TOMORROW: "tomorrow",
  NEXT_WEEK: "next-week",
  NEXT_MONTH: "next-month",
  CUSTOM: "custom"
};

export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,
  name: null,
  selectedReminderType: null,

  onShow() {
    this.setProperties({
      errorMessage: null,
      loading: true,
      name: null,
      selectedReminderType: null
    });

    this.set("loading", false);
  },

  saveBookmark() {
    let promise = new Promise(resolve => {
      resolve();
    });
    return promise;
  },

  @discourseComputed()
  usingMobileDevice() {
    return this.site.mobileView;
  },

  @discourseComputed()
  reminderTypes() {
    return REMINDER_TYPES;
  },

  @discourseComputed()
  showLaterToday() {
    return !this.laterToday().isSame(this.tomorrow(), "date");
  },

  @discourseComputed()
  laterTodayFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.later_today", {
        date: this.laterToday().format(I18n.t("dates.time"))
      })
    );
  },

  @discourseComputed()
  tomorrowFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.tomorrow", {
        date: this.tomorrow().format(I18n.t("dates.time_short_day"))
      })
    );
  },

  @discourseComputed()
  nextBusinessDayFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.next_business_day", {
        date: this.nextBusinessDay().format(I18n.t("dates.time_short_day"))
      })
    );
  },

  @discourseComputed()
  nextWeekFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.next_week", {
        date: this.nextWeek().format(I18n.t("dates.month_day_time"))
      })
    );
  },

  @discourseComputed()
  nextMonthFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.next_month", {
        date: this.nextMonth().format(I18n.t("dates.month_day_time"))
      })
    );
  },

  nextWeek() {
    return this.startOfDay(this.now().add(7, "days"));
  },

  nextMonth() {
    return this.startOfDay(this.now().add(1, "month"));
  },

  nextBusinessDay() {
    const currentDay = this.now().isoWeekday(); // 1=Mon, 7=Sun
    let next = null;
    if (currentDay === 5) { // friday
      next = this.now().add(3, "days");
    } else if (currentDay === 6) { // saturday {
      next = this.now().add(2, "days");
    } else {
      next = this.now().add(1, "day");
    }

    return this.startOfDay(next);
  },

  tomorrow() {
    return this.startOfDay(this.now().add(1, "day"));
  },

  startOfDay(momentDate) {
    return momentDate.hour(START_OF_DAY_HOUR).startOf("hour");
  },

  userTimezone() {
    return this.currentUser.timezone;
  },

  now() {
    return moment().tz(this.userTimezone());
  },

  laterToday() {
    let later = this.now().add(3, "hours");
    return later.minutes() < 30 ? later.minutes(30) : later.add(30, "minutes").startOf("hour");
  },

  actions: {
    saveAndClose() {
      this.saveBookmark().then(() => {
        this.send("closeModal");
      });
    },

    closeWithoutSavingBookmark() {
      this.send("closeModal");
    },

    selectReminderType(type) {
      this.set("selectedReminderType", type);
    }
  }
});
