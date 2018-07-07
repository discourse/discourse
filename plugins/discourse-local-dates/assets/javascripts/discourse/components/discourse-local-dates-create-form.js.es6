import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  timeFormat: "HH:mm",
  dateFormat: "YYYY-MM-DD",
  dateTimeFormat: "YYYY-MM-DD HH:mm",
  config: null,
  date: null,
  toDate: null,
  time: null,
  toTime: null,
  format: null,
  formats: null,
  recurring: null,
  advancedMode: false,

  init() {
    this._super();

    this.set("date", moment().format(this.dateFormat));
    this.set("format", `LLL`);
    this.set(
      "timezones",
      (this.siteSettings.discourse_local_dates_default_timezones || "")
        .split("|")
        .filter(f => f)
    );
    this.set(
      "formats",
      (this.siteSettings.discourse_local_dates_default_formats || "").split("|")
    );
  },

  didInsertElement() {
    this._super();

    this._setConfig();
  },

  @computed
  currentUserTimezone() {
    return moment.tz.guess();
  },

  @computed("formats")
  previewedFormats(formats) {
    return formats.map(format => {
      return {
        format: format,
        preview: moment().format(format)
      };
    });
  },

  @computed
  recurringOptions() {
    return [
      { name: "Every day", id: "1.days" },
      { name: "Every week", id: "1.weeks" },
      { name: "Every two weeks", id: "2.weeks" },
      { name: "Every month", id: "1.months" },
      { name: "Every two months", id: "2.months" },
      { name: "Every three months", id: "3.months" },
      { name: "Every six months", id: "6.months" },
      { name: "Every year", id: "1.years" }
    ];
  },

  @computed()
  allTimezones() {
    return _.map(moment.tz.names(), z => z);
  },

  @observes(
    "date",
    "time",
    "toDate",
    "toTime",
    "recurring",
    "format",
    "timezones"
  )
  _setConfig() {
    const toTime = this.get("toTime");

    if (toTime && !this.get("toDate")) {
      this.set("toDate", moment().format(this.dateFormat));
    }

    const date = this.get("date");
    const toDate = this.get("toDate");
    const time = this.get("time");
    const recurring = this.get("recurring");
    const format = this.get("format");
    const timezones = this.get("timezones");

    let dateTime;

    if (time) {
      dateTime = moment(`${date} ${time}`, this.dateTimeFormat).utc();
    } else {
      dateTime = moment(date, this.dateFormat).startOf("day");
    }

    let toDateTime;
    if (toTime) {
      toDateTime = moment(`${toDate} ${toTime}`, this.dateTimeFormat).utc();
    } else {
      toDateTime = moment(toDate, this.dateFormat).endOf("day");
    }

    let config = {
      date: dateTime.format(this.dateFormat),
      dateTime,
      recurring,
      format,
      timezones
    };

    if (time) {
      config.time = dateTime.format(this.timeFormat);
    }

    if (toDate) {
      config.toDate = toDateTime.format(this.dateFormat);
    }

    if (toTime) {
      config.toTime = toDateTime.format(this.timeFormat);
    }

    if (!time && !toTime && this.get("formats").includes(format)) {
      config.format = "LL";
    }

    if (toDate) {
      config.toDateTime = toDateTime;
    }

    if (
      time &&
      toTime &&
      date === moment().format(this.dateFormat) &&
      date === toDate &&
      this.get("formats").includes(format)
    ) {
      config.format = "LT";
    }

    this.set("config", config);
  },

  getTextConfig(config) {
    let text = `[date=${config.date} `;
    if (config.recurring) text += `recurring=${config.recurring} `;

    if (config.time) {
      text += `time=${config.time} `;
    }

    text += `format="${config.format}" `;
    text += `timezones="${config.timezones.join("|")}"`;
    text += `]`;

    if (config.toDate) {
      text += ` → `;
      text += `[date=${config.toDate} `;

      if (config.toTime) {
        text += `time=${config.toTime} `;
      }

      text += `format="${config.format}" `;
      text += `timezones="${config.timezones.join("|")}"`;
      text += `]`;
    }

    return text;
  },

  @computed("config.dateTime", "config.toDateTime")
  validDate(dateTime, toDateTime) {
    if (!dateTime) return false;

    if (toDateTime) {
      if (!toDateTime.isValid()) {
        return false;
      }

      if (toDateTime.diff(dateTime) < 0) {
        return false;
      }
    }

    return dateTime.isValid();
  },

  @computed("advancedMode")
  toggleModeBtnLabel(advancedMode) {
    return advancedMode
      ? "discourse_local_dates.create.form.simple_mode"
      : "discourse_local_dates.create.form.advanced_mode";
  },

  actions: {
    advancedMode() {
      this.toggleProperty("advancedMode");
    },

    save() {
      this._closeModal();

      const textConfig = this.getTextConfig(this.get("config"));
      this.get("toolbarEvent").addText(textConfig);
    },

    fillFormat(format) {
      this.set("format", format);
    },

    cancel() {
      this._closeModal();
    }
  },

  _closeModal() {
    const composer = Discourse.__container__.lookup("controller:composer");
    composer.send("closeModal");
  }
});
