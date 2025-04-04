import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import EmberObject, { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { observes } from "@ember-decorators/object";
import CalendarDateTimeInput from "discourse/components/calendar-date-time-input";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import TextField from "discourse/components/text-field";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { propertyNotEqual } from "discourse/lib/computed";
import computed, { debounce } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import { applyLocalDates } from "discourse/lib/local-dates";
import { cook } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import MultiSelect from "select-kit/components/multi-select";
import TimezoneInput from "select-kit/components/timezone-input";
import generateDateMarkup from "discourse/plugins/discourse-local-dates/lib/local-date-markup-generator";

export default class LocalDatesCreate extends Component {
  timeFormat = "HH:mm:ss";
  dateFormat = "YYYY-MM-DD";
  dateTimeFormat = "YYYY-MM-DD HH:mm:ss";
  date = null;
  toDate = null;
  time = null;
  toTime = null;
  format = null;
  formats = null;
  recurring = null;
  advancedMode = false;
  timezone = null;
  fromSelected = null;
  toSelected = null;

  @notEmpty("date") fromFilled;
  @notEmpty("toDate") toFilled;
  @propertyNotEqual("currentUserTimezone", "options.timezone")
  timezoneIsDifferentFromUserTimezone;

  init() {
    super.init(...arguments);

    this._picker = null;

    this.setProperties({
      timezones: [],
      formats: (this.siteSettings.discourse_local_dates_default_formats || "")
        .split("|")
        .filter((f) => f),
      timezone: this.currentUserTimezone,
      date: moment().format(this.dateFormat),
    });
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.send("focusFrom");
  }

  @observes("computedConfig.{from,to,options}", "options", "isValid", "isRange")
  configChanged() {
    this._renderPreview();
  }

  @debounce(INPUT_DELAY)
  async _renderPreview() {
    if (this.markup) {
      const result = await cook(this.markup);
      this.set("currentPreview", result);

      schedule("afterRender", () => {
        applyLocalDates(
          document.querySelectorAll(".preview .discourse-local-date"),
          this.siteSettings
        );
      });
    }
  }

  @computed("date", "toDate", "toTime")
  isRange(date, toDate, toTime) {
    return date && (toDate || toTime);
  }

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
  }

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

    return EmberObject.create({
      date: dateTime.format(this.dateFormat),
      time,
      dateTime,
      format,
      range: isRange ? "start" : false,
    });
  }

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

    return EmberObject.create({
      date: dateTime.format(this.dateFormat),
      time,
      dateTime,
      format,
      range: isRange ? "end" : false,
    });
  }

  @computed("recurring", "timezones", "timezone", "format")
  options(recurring, timezones, timezone, format) {
    return EmberObject.create({
      recurring,
      timezones,
      timezone,
      format,
    });
  }

  @computed(
    "fromConfig.{date}",
    "toConfig.{date}",
    "options.{recurring,timezones,timezone,format}"
  )
  computedConfig(fromConfig, toConfig, options) {
    return EmberObject.create({
      from: fromConfig,
      to: toConfig,
      options,
    });
  }

  @computed
  currentUserTimezone() {
    return this.currentUser.user_option.timezone || moment.tz.guess();
  }

  @computed
  allTimezones() {
    return moment.tz.names();
  }

  @computed("currentUserTimezone")
  formattedCurrentUserTimezone(timezone) {
    return timezone.replace("_", " ").replace("Etc/", "").replace("/", ", ");
  }

  @computed("formats")
  previewedFormats(formats) {
    return formats.map((format) => {
      return {
        format,
        preview: moment().format(format),
      };
    });
  }

  @computed
  recurringOptions() {
    const key = "discourse_local_dates.create.form.recurring";

    return [
      {
        name: i18n(`${key}.every_day`),
        id: "1.days",
      },
      {
        name: i18n(`${key}.every_week`),
        id: "1.weeks",
      },
      {
        name: i18n(`${key}.every_two_weeks`),
        id: "2.weeks",
      },
      {
        name: i18n(`${key}.every_month`),
        id: "1.months",
      },
      {
        name: i18n(`${key}.every_two_months`),
        id: "2.months",
      },
      {
        name: i18n(`${key}.every_three_months`),
        id: "3.months",
      },
      {
        name: i18n(`${key}.every_six_months`),
        id: "6.months",
      },
      {
        name: i18n(`${key}.every_year`),
        id: "1.years",
      },
    ];
  }

  _generateDateMarkup(fromDateTime, options, isRange, toDateTime) {
    return generateDateMarkup(fromDateTime, options, isRange, toDateTime);
  }

  @computed("advancedMode")
  toggleModeBtnLabel(advancedMode) {
    return advancedMode
      ? "discourse_local_dates.create.form.simple_mode"
      : "discourse_local_dates.create.form.advanced_mode";
  }

  @computed("computedConfig.{from,to,options}", "options", "isValid", "isRange")
  markup(config, options, isValid, isRange) {
    let text;

    if (isValid && config.from) {
      if (config.to && config.to.range) {
        text = this._generateDateMarkup(
          config.from,
          options,
          isRange,
          config.to
        );
      } else {
        text = this._generateDateMarkup(config.from, options, isRange);
      }
    }
    return text;
  }

  @computed("fromConfig.dateTime")
  formattedFrom(dateTime) {
    return dateTime.format("LLLL");
  }

  @computed("toConfig.dateTime")
  formattedTo(dateTime) {
    return dateTime.isValid()
      ? dateTime.format("LLLL")
      : i18n("discourse_local_dates.create.form.until");
  }

  @action
  updateFormat(format, event) {
    event?.preventDefault();
    this.set("format", format);
  }

  @computed("fromSelected", "toSelected")
  selectedDate(fromSelected) {
    return fromSelected ? this.date : this.toDate;
  }

  @computed("fromSelected", "toSelected")
  selectedTime(fromSelected) {
    return fromSelected ? this.time : this.toTime;
  }

  @action
  changeSelectedDate(date) {
    if (this.fromSelected) {
      this.set("date", date);
    } else {
      this.set("toDate", date);
    }
  }

  @action
  changeSelectedTime(time) {
    if (this.fromSelected) {
      this.set("time", time);
    } else {
      this.set("toTime", time);
    }
  }

  @action
  eraseToDateTime() {
    this.setProperties({
      toDate: null,
      toTime: null,
    });
    this.focusFrom();
  }

  @action
  focusFrom() {
    this.setProperties({
      fromSelected: true,
      toSelected: false,
      minDate: null,
    });
  }

  @action
  focusTo() {
    this.setProperties({
      toSelected: true,
      fromSelected: false,
      minDate: this.get("fromConfig.date"),
    });
  }

  @action
  toggleAdvancedMode() {
    this.toggleProperty("advancedMode");
  }

  @action
  save() {
    const markup = this.markup;

    if (markup) {
      this.closeModal();
      this.model.insertDate(markup);
    }
  }

  @action
  cancel() {
    this.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "discourse_local_dates.title"}}
      @closeModal={{@closeModal}}
      class="discourse-local-dates-create-modal -large"
    >
      <:body>
        <div class="form">
          {{#if this.isValid}}
            {{#if this.timezoneIsDifferentFromUserTimezone}}
              <div class="preview alert alert-info">
                {{i18n "discourse_local_dates.create.form.current_timezone"}}
                <b
                >{{this.formattedCurrentUserTimezone}}</b>{{this.currentPreview}}
              </div>
            {{/if}}
          {{else}}
            <div class="validation-error alert alert-error">
              {{i18n "discourse_local_dates.create.form.invalid_date"}}
            </div>
          {{/if}}

          {{this.computeDate}}

          <div class="date-time-configuration">
            <div class="inputs-panel">
              <div
                class="date-time-control from
                  {{if this.fromSelected 'is-selected'}}
                  {{if this.fromFilled 'is-filled'}}"
              >
                {{icon "calendar-days"}}
                <DButton
                  @action={{this.focusFrom}}
                  @translatedLabel={{this.formattedFrom}}
                  id="from-date-time"
                  class="date-time"
                  autofocus
                />
              </div>

              <div
                class="date-time-control to
                  {{if this.toSelected 'is-selected'}}
                  {{if this.toFilled 'is-filled'}}"
              >
                {{icon "calendar-days"}}
                <DButton
                  @action={{this.focusTo}}
                  @translatedLabel={{this.formattedTo}}
                  class="date-time"
                />
                {{#if this.toFilled}}
                  <DButton
                    @action={{this.eraseToDateTime}}
                    @icon="xmark"
                    class="delete-to-date"
                  />
                {{/if}}
              </div>

              {{#if this.site.desktopView}}
                <TimezoneInput
                  @options={{hash icon="globe"}}
                  @value={{this.timezone}}
                  @onChange={{fn (mut this.timezone)}}
                />
              {{/if}}
            </div>

            <div class="picker-panel">
              <CalendarDateTimeInput
                @datePickerId="local-date-create-form"
                @date={{this.selectedDate}}
                @time={{this.selectedTime}}
                @minDate={{this.minDate}}
                @timeFormat={{this.timeFormat}}
                @dateFormat={{this.dateFormat}}
                @onChangeDate={{this.changeSelectedDate}}
                @onChangeTime={{this.changeSelectedTime}}
              />
            </div>

            {{#if this.site.mobileView}}
              <TimezoneInput
                @value={{this.timezone}}
                @options={{hash icon="globe"}}
                @onChange={{fn (mut this.timezone)}}
              />
            {{/if}}
          </div>

          {{#if this.advancedMode}}
            <div class="advanced-options">
              {{#unless this.isRange}}
                <div class="control-group recurrence">
                  <label class="control-label">
                    {{i18n "discourse_local_dates.create.form.recurring_title"}}
                  </label>
                  <p>{{htmlSafe
                      (i18n
                        "discourse_local_dates.create.form.recurring_description"
                      )
                    }}</p>
                  <div class="controls">
                    <ComboBox
                      @content={{this.recurringOptions}}
                      @value={{this.recurring}}
                      @onChange={{fn (mut this.recurring)}}
                      @options={{hash
                        none="discourse_local_dates.create.form.recurring_none"
                      }}
                      class="recurrence-input"
                    />
                  </div>
                </div>
              {{/unless}}

              <div class="control-group timezones">
                <label>{{i18n
                    "discourse_local_dates.create.form.timezones_title"
                  }}</label>
                <p>{{i18n
                    "discourse_local_dates.create.form.timezones_description"
                  }}</p>
                <div class="controls">
                  <MultiSelect
                    @valueProperty={{null}}
                    @nameProperty={{null}}
                    @content={{this.allTimezones}}
                    @value={{this.timezones}}
                    @options={{hash allowAny=false maximum=5}}
                    class="timezones-input"
                  />
                </div>
              </div>

              <div class="control-group format">
                <label>{{i18n
                    "discourse_local_dates.create.form.format_title"
                  }}</label>
                <p>
                  {{i18n
                    "discourse_local_dates.create.form.format_description"
                  }}
                  <a
                    target="_blank"
                    href="https://momentjs.com/docs/#/parsing/string-format/"
                    rel="noopener noreferrer"
                  >
                    {{icon "circle-question"}}
                  </a>
                </p>
                <div class="controls">
                  <TextField @value={{this.format}} class="format-input" />
                </div>
              </div>
              <div class="control-group">
                <ul class="formats">
                  {{#each this.previewedFormats as |previewedFormat|}}
                    <li class="format">
                      <a
                        class="moment-format"
                        href
                        {{on
                          "click"
                          (fn this.updateFormat previewedFormat.format)
                        }}
                      >
                        {{previewedFormat.format}}
                      </a>
                      <span class="previewed-format">
                        {{previewedFormat.preview}}
                      </span>
                    </li>
                  {{/each}}
                </ul>
              </div>
            </div>
          {{/if}}
        </div>
      </:body>

      <:footer>

        {{#if this.isValid}}
          <DButton
            @action={{this.save}}
            @label="discourse_local_dates.create.form.insert"
            class="btn-primary"
          />
        {{/if}}

        <DButton
          @action={{this.cancel}}
          @translatedLabel={{i18n "cancel"}}
          class="btn-flat"
        />

        <DButton
          @action={{this.toggleAdvancedMode}}
          @icon="gear"
          @label={{this.toggleModeBtnLabel}}
          class="btn-default advanced-mode-btn"
        />
      </:footer>
    </DModal>
  </template>
}
