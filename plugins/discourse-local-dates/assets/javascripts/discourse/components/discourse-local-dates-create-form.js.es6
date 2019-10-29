import Component from "@ember/component";
/* global Pikaday:true */
import { propertyNotEqual } from "discourse/lib/computed";
import loadScript from "discourse/lib/load-script";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { cookAsync } from "discourse/lib/text";
import debounce from "discourse/lib/debounce";

export default Component.extend({
  timeFormat: "HH:mm:ss",
  dateFormat: "YYYY-MM-DD",
  dateTimeFormat: "YYYY-MM-DD HH:mm:ss",
  date: null,
  toDate: null,
  time: null,
  toTime: null,
  format: null,
  formats: null,
  recurring: null,
  advancedMode: false,
  isValid: true,
  timezone: null,
  fromSelected: null,
  fromFilled: Ember.computed.notEmpty("date"),
  toSelected: null,
  toFilled: Ember.computed.notEmpty("toDate"),

  init() {
    this._super(...arguments);

    this._picker = null;

    this.setProperties({
      timezones: [],
      formats: (this.siteSettings.discourse_local_dates_default_formats || "")
        .split("|")
        .filter(f => f),
      timezone: moment.tz.guess(),
      date: moment().format(this.dateFormat)
    });
  },

  didInsertElement() {
    this._super(...arguments);

    this._setupPicker().then(picker => {
      this._picker = picker;
      this.send("focusFrom");
    });
  },

  _renderPreview: debounce(function() {
    const markup = this.markup;

    if (markup) {
      cookAsync(markup).then(result => {
        this.set("currentPreview", result);
        Ember.run.schedule("afterRender", () =>
          this.$(".preview .discourse-local-date").applyLocalDates()
        );
      });
    }
  }, 250).observes("markup"),

  @computed("date", "toDate", "toTime")
  isRange(date, toDate, toTime) {
    return date && (toDate || toTime);
  },

  @computed("computedConfig", "isRange")
  isValid(config, isRange) {
    const fromConfig = config.from;
    if (!config.from.dateTime || !config.from.dateTime.isValid()) {
      return false;
    }

    if (isRange) {
      const toConfig = config.to;

      if (
        !toConfig.dateTime ||
        !toConfig.dateTime.isValid() ||
        toConfig.dateTime.diff(fromConfig.dateTime) < 0
      ) {
        return false;
      }
    }

    return true;
  },

  @computed("date", "time", "isRange", "options.{format,timezone}")
  fromConfig(date, time, isRange, options = {}) {
    const timeInferred = time ? false : true;

    let dateTime;
    if (!timeInferred) {
      dateTime = moment.tz(`${date} ${time}`, options.timezone);
    } else {
      dateTime = moment.tz(date, options.timezone);
    }

    if (!timeInferred) {
      time = dateTime.format(this.timeFormat);
    }

    let format = options.format;
    if (timeInferred && this.formats.includes(format)) {
      format = "LL";
    }

    return Ember.Object.create({
      date: dateTime.format(this.dateFormat),
      time,
      dateTime,
      format,
      range: isRange ? "start" : false
    });
  },

  @computed("toDate", "toTime", "isRange", "options.{timezone,format}")
  toConfig(date, time, isRange, options = {}) {
    const timeInferred = time ? false : true;

    if (time && !date) {
      date = moment().format(this.dateFormat);
    }

    let dateTime;
    if (!timeInferred) {
      dateTime = moment.tz(`${date} ${time}`, options.timezone);
    } else {
      dateTime = moment.tz(date, options.timezone).endOf("day");
    }

    if (!timeInferred) {
      time = dateTime.format(this.timeFormat);
    }

    let format = options.format;
    if (timeInferred && this.formats.includes(format)) {
      format = "LL";
    }

    return Ember.Object.create({
      date: dateTime.format(this.dateFormat),
      time,
      dateTime,
      format,
      range: isRange ? "end" : false
    });
  },

  @computed("recurring", "timezones", "timezone", "format")
  options(recurring, timezones, timezone, format) {
    return Ember.Object.create({
      recurring,
      timezones,
      timezone,
      format
    });
  },

  @computed(
    "fromConfig.{date}",
    "toConfig.{date}",
    "options.{recurring,timezones,timezone,format}"
  )
  computedConfig(fromConfig, toConfig, options) {
    return Ember.Object.create({
      from: fromConfig,
      to: toConfig,
      options
    });
  },

  @computed
  currentUserTimezone() {
    return moment.tz.guess();
  },

  @computed
  allTimezones() {
    return moment.tz.names();
  },

  timezoneIsDifferentFromUserTimezone: propertyNotEqual(
    "currentUserTimezone",
    "options.timezone"
  ),

  @computed("currentUserTimezone")
  formatedCurrentUserTimezone(timezone) {
    return timezone
      .replace("_", " ")
      .replace("Etc/", "")
      .split("/");
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
    const key = "discourse_local_dates.create.form.recurring";

    return [
      {
        name: I18n.t(`${key}.every_day`),
        id: "1.days"
      },
      {
        name: I18n.t(`${key}.every_week`),
        id: "1.weeks"
      },
      {
        name: I18n.t(`${key}.every_two_weeks`),
        id: "2.weeks"
      },
      {
        name: I18n.t(`${key}.every_month`),
        id: "1.months"
      },
      {
        name: I18n.t(`${key}.every_two_months`),
        id: "2.months"
      },
      {
        name: I18n.t(`${key}.every_three_months`),
        id: "3.months"
      },
      {
        name: I18n.t(`${key}.every_six_months`),
        id: "6.months"
      },
      {
        name: I18n.t(`${key}.every_year`),
        id: "1.years"
      }
    ];
  },

  _generateDateMarkup(config, options, isRange) {
    let text = `[date=${config.date}`;

    if (config.time) {
      text += ` time=${config.time}`;
    }

    if (config.format && config.format.length) {
      text += ` format="${config.format}"`;
    }

    if (options.timezone) {
      text += ` timezone="${options.timezone}"`;
    }

    if (options.timezones && options.timezones.length) {
      text += ` timezones="${options.timezones.join("|")}"`;
    }

    if (options.recurring && !isRange) {
      text += ` recurring="${options.recurring}"`;
    }

    text += `]`;

    return text;
  },

  @computed("advancedMode")
  toggleModeBtnLabel(advancedMode) {
    return advancedMode
      ? "discourse_local_dates.create.form.simple_mode"
      : "discourse_local_dates.create.form.advanced_mode";
  },

  @computed("computedConfig.{from,to,options}", "options", "isValid", "isRange")
  markup(config, options, isValid, isRange) {
    let text;

    if (isValid && config.from) {
      text = this._generateDateMarkup(config.from, options, isRange);

      if (config.to && config.to.range) {
        text += ` → `;
        text += this._generateDateMarkup(config.to, options, isRange);
      }
    }

    return text;
  },

  @computed("fromConfig.dateTime")
  formattedFrom(dateTime) {
    return dateTime.format("LLLL");
  },

  @computed("toConfig.dateTime", "toSelected")
  formattedTo(dateTime, toSelected) {
    const emptyText = toSelected
      ? "&nbsp;"
      : I18n.t("discourse_local_dates.create.form.until");

    return dateTime.isValid() ? dateTime.format("LLLL") : emptyText;
  },

  actions: {
    setTime(event) {
      this._setTimeIfValid(event.target.value, "time");
    },

    setToTime(event) {
      this._setTimeIfValid(event.target.value, "toTime");
    },

    eraseToDateTime() {
      this.setProperties({ toDate: null, toTime: null });
      this._setPickerDate(null);
    },

    focusFrom() {
      this.setProperties({ fromSelected: true, toSelected: false });
      this._setPickerDate(this.get("fromConfig.date"));
      this._setPickerMinDate(null);
    },

    focusTo() {
      this.setProperties({ toSelected: true, fromSelected: false });
      this._setPickerDate(this.get("toConfig.date"));
      this._setPickerMinDate(this.get("fromConfig.date"));
    },

    advancedMode() {
      this.toggleProperty("advancedMode");
    },

    save() {
      const markup = this.markup;

      if (markup) {
        this._closeModal();
        this.toolbarEvent.addText(markup);
      }
    },

    cancel() {
      this._closeModal();
    }
  },

  _setTimeIfValid(time, key) {
    if (Ember.isEmpty(time)) {
      this.set(key, null);
      return;
    }

    if (/^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/.test(time)) {
      this.set(key, time);
    }
  },

  _setupPicker() {
    return new Ember.RSVP.Promise(resolve => {
      loadScript("/javascripts/pikaday.js").then(() => {
        const options = {
          field: this.$(`.fake-input`)[0],
          container: this.$(`#picker-container-${this.elementId}`)[0],
          bound: false,
          format: "YYYY-MM-DD",
          reposition: false,
          firstDay: 1,
          setDefaultDate: true,
          keyboardInput: false,
          i18n: {
            previousMonth: I18n.t("dates.previous_month"),
            nextMonth: I18n.t("dates.next_month"),
            months: moment.months(),
            weekdays: moment.weekdays(),
            weekdaysShort: moment.weekdaysMin()
          },
          onSelect: date => {
            const formattedDate = moment(date).format("YYYY-MM-DD");

            if (this.fromSelected) {
              this.set("date", formattedDate);
            }

            if (this.toSelected) {
              this.set("toDate", formattedDate);
            }
          }
        };

        resolve(new Pikaday(options));
      });
    });
  },

  _setPickerMinDate(date) {
    if (date && !moment(date, this.dateFormat).isValid()) {
      date = null;
    }

    Ember.run.schedule("afterRender", () => {
      this._picker.setMinDate(moment(date, this.dateFormat).toDate());
    });
  },

  _setPickerDate(date) {
    if (date && !moment(date, this.dateFormat).isValid()) {
      date = null;
    }

    Ember.run.schedule("afterRender", () => {
      this._picker.setDate(moment.utc(date), true);
    });
  },

  _closeModal() {
    const composer = Discourse.__container__.lookup("controller:composer");
    composer.send("closeModal");
  }
});
