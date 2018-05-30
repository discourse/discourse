import computed from "ember-addons/ember-computed-decorators";
import { observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  timeFormat: "HH:mm",
  dateFormat: "YYYY-MM-DD",
  dateTimeFormat: "YYYY-MM-DD HH:mm",
  config: null,
  date: null,
  time: null,
  format: null,
  formats: null,
  recurring: null,
  advancedMode: false,

  init() {
    this._super();

    this.set("date", moment().format(this.dateFormat));
    this.set("time", moment().format(this.timeFormat));
    this.set("format", `LLL`);
    this.set("timezones", (this.siteSettings.discourse_local_dates_default_timezones || "").split("|").filter(f => f));
    this.set("formats", (this.siteSettings.discourse_local_dates_default_formats || "").split("|"));
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
      { name: "Every year", id: "1.years" },
    ];
  },

  @computed()
  allTimezones() {
    return _.map(moment.tz.names(), (z) => z);
  },

  @observes("date", "time", "recurring", "format", "timezones")
  _setConfig() {
    const date = this.get("date");
    const time = this.get("time");
    const recurring = this.get("recurring");
    const format = this.get("format");
    const timezones = this.get("timezones");
    const dateTime = moment(`${date} ${time}`, this.dateTimeFormat).utc();

    this.set("config", {
      date: dateTime.format(this.dateFormat),
      time: dateTime.format(this.timeFormat),
      dateTime,
      recurring,
      format,
      timezones,
    });
  },

  getTextConfig(config) {
    let text = `[date=${config.date} `;
    if (config.recurring) text += `recurring=${config.recurring} `;
    text += `time=${config.time} `;
    text += `format="${config.format}" `;
    text += `timezones="${config.timezones.join("|")}"`;
    text += `]`;
    return text;
  },

  @computed("config.dateTime")
  validDate(dateTime) {
    if (!dateTime) return false;
    return dateTime.isValid();
  },

  @computed("advancedMode")
  toggleModeBtnLabel(advancedMode) {
    return advancedMode ? "discourse_local_dates.create.form.simple_mode" : "discourse_local_dates.create.form.advanced_mode";
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
