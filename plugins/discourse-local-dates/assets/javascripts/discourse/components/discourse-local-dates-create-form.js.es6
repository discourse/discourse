import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  timeFormat: "HH:mm:ss",
  dateFormat: "YYYY-MM-DD",
  dateTimeFormat: "YYYY-MM-DD HH:mm:ss",
  config: null,
  date: null,
  toDate: null,
  time: null,
  toTime: null,
  format: null,
  formats: null,
  recurring: null,
  advancedMode: false,
  isValid: true,

  init() {
    this._super();

    this.set("date", moment().format(this.dateFormat));
    this.set("timezones", []);
    this.set(
      "formats",
      (this.siteSettings.discourse_local_dates_default_formats || "")
        .split("|")
        .filter(f => f)
    );
  },

  @observes("date", "time", "toDate", "toTime")
  _resetFormValidity() {
    this.set("isValid", true);
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
    return moment.tz.names();
  },

  getConfig(range) {
    const endOfRange = range && range === "end";
    const time = endOfRange ? this.get("toTime") : this.get("time");
    let date = endOfRange ? this.get("toDate") : this.get("date");

    if (endOfRange && time && !date) {
      date = moment().format(this.dateFormat);
    }

    const recurring = this.get("recurring");
    const format = this.get("format");
    const timezones = this.get("timezones");
    const timeInferred = time ? false : true;
    const timezone = this.get("currentUserTimezone");

    let dateTime;
    if (!timeInferred) {
      dateTime = moment.tz(`${date} ${time}`, timezone);
    } else {
      if (endOfRange) {
        dateTime = moment.tz(date, timezone).endOf("day");
      } else {
        dateTime = moment.tz(date, timezone);
      }
    }

    let config = {
      date: dateTime.format(this.dateFormat),
      dateTime,
      recurring,
      format,
      timezones,
      timezone
    };

    if (!timeInferred) {
      config.time = dateTime.format(this.timeFormat);
    }

    if (timeInferred) {
      config.displayedTimezone = this.get("currentUserTimezone");
    }

    if (timeInferred && this.get("formats").includes(format)) {
      config.format = "LL";
    }

    return config;
  },

  _generateDateMarkup(config) {
    let text = `[date=${config.date}`;

    if (config.time) {
      text += ` time=${config.time} `;
    }

    if (config.format && config.format.length) {
      text += ` format="${config.format}" `;
    }

    if (config.timezone) {
      text += ` timezone="${config.timezone}"`;
    }

    if (config.timezones && config.timezones.length) {
      text += ` timezones="${config.timezones.join("|")}"`;
    }

    if (config.recurring) {
      text += ` recurring="${config.recurring}"`;
    }

    text += `]`;

    return text;
  },

  valid(isRange) {
    const fromConfig = this.getConfig(isRange ? "start" : null);

    if (!fromConfig.dateTime || !fromConfig.dateTime.isValid()) {
      this.set("isValid", false);
      return false;
    }

    if (isRange) {
      const toConfig = this.getConfig("end");

      if (
        !toConfig.dateTime ||
        !toConfig.dateTime.isValid() ||
        toConfig.dateTime.diff(fromConfig.dateTime) < 0
      ) {
        this.set("isValid", false);
        return false;
      }
    }

    this.set("isValid", true);
    return true;
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
      const isRange =
        this.get("date") && (this.get("toDate") || this.get("toTime"));

      if (this.valid(isRange)) {
        this._closeModal();

        let text = this._generateDateMarkup(
          this.getConfig(isRange ? "start" : null)
        );

        if (isRange) {
          text += ` → `;
          text += this._generateDateMarkup(this.getConfig("end"));
        }

        this.get("toolbarEvent").addText(text);
      }
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
