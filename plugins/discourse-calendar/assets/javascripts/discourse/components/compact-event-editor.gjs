import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CompactEventEditor extends Component {
  @service capabilities;

  @tracked _maxAttendeesOverride;

  get displayTime() {
    if (!this.args.startsAt) {
      return null;
    }
    return this.args.startsAt.clone().tz(this.args.userTimezone);
  }

  get displayEndTime() {
    if (!this.args.endsAt) {
      return null;
    }
    return this.args.endsAt.clone().tz(this.args.userTimezone);
  }

  get hasEndDate() {
    return !!this.args.endsAt;
  }

  get isMultiDay() {
    const start = this.formattedStartDate;
    const end = this.formattedEndDate;
    return !!start && !!end && start !== end;
  }

  get showInlineEndTime() {
    return !this.args.allDay && !this.isMultiDay;
  }

  get showEndDateRow() {
    return this.args.allDay || this.isMultiDay;
  }

  get formattedStartDisplay() {
    if (!this.displayTime) {
      return "";
    }
    return this.displayTime.format(i18n("dates.long_no_year_no_time"));
  }

  get formattedEndDisplay() {
    if (!this.displayEndTime) {
      return i18n("discourse_post_event.composer.end_date_placeholder");
    }
    return this.displayEndTime.format(i18n("dates.long_no_year_no_time"));
  }

  get startsAtMonth() {
    const m = this.displayTime || moment.tz(this.args.userTimezone);
    return m.format("MMM");
  }

  get startsAtDay() {
    const m = this.displayTime || moment.tz(this.args.userTimezone);
    return m.format("D");
  }

  get hasLocation() {
    return this.args.location && this.args.location.trim();
  }

  get isLocationUrl() {
    if (!this.hasLocation) {
      return false;
    }
    return this.args.urlTester?.(this.args.location) ?? false;
  }

  get locationIcon() {
    return this.isLocationUrl ? "link" : "location-pin";
  }

  get displayLocation() {
    if (!this.hasLocation) {
      return null;
    }
    if (this.isLocationUrl) {
      const location = this.args.location.trim();
      return location.includes("://") || location.includes("mailto:")
        ? location
        : `https://${location}`;
    }
    return this.args.location;
  }

  formatDate(m) {
    if (!m || typeof m.isValid !== "function" || !m.isValid()) {
      return "";
    }
    return m.format("YYYY-MM-DD");
  }

  formatTime(m) {
    if (!m || typeof m.isValid !== "function" || !m.isValid()) {
      return "";
    }
    return m.format("HH:mm");
  }

  get formattedStartDate() {
    return this.formatDate(this.args.startsAt);
  }

  get formattedEndDate() {
    return this.formatDate(this.args.endsAt);
  }

  get formattedStartTime() {
    return this.formatTime(this.args.startsAt);
  }

  get formattedEndTime() {
    return this.formatTime(this.args.endsAt);
  }

  combineDateTime(dateStr, timeStr) {
    const date = (dateStr || "").trim();
    if (!date) {
      return null;
    }
    const time = (timeStr || "").trim();
    const tz = this.args.timezone || "UTC";
    return moment.tz(time ? `${date} ${time}` : date, tz);
  }

  @action
  onNameInput(event) {
    event.target.value = event.target.value.replace(/\n/g, "");
    this.args.onUpdateName?.(event.target.value);
  }

  @action
  onLocationInput(event) {
    const value = event.target.value;
    this.args.onUpdateLocation?.(value === "" ? null : value);
  }

  @action
  onDescriptionInput(event) {
    this.args.onUpdateDescription?.(event.target.value);
  }

  startTimeForDate() {
    return this.args.allDay ? "" : this.formattedStartTime || "00:00";
  }

  endTimeForDate() {
    return this.args.allDay ? "" : this.formattedEndTime || "00:00";
  }

  @action
  onStartDateChange(event) {
    const dateStr = event.target.value;
    const m = this.combineDateTime(dateStr, this.startTimeForDate());
    if (!m) {
      return;
    }
    this.args.onUpdateStart?.(m);

    if (this.showInlineEndTime) {
      this.args.onUpdateEnd?.(
        this.combineDateTime(dateStr, this.endTimeForDate())
      );
      return;
    }

    const endDateStr = this.formattedEndDate;
    if (endDateStr && dateStr > endDateStr) {
      this.args.onUpdateEnd?.(
        this.combineDateTime(dateStr, this.endTimeForDate())
      );
    }
  }

  @action
  onStartTimeChange(event) {
    const m = this.combineDateTime(
      this.formattedStartDate,
      event.target.value || "00:00"
    );
    if (m) {
      this.args.onUpdateStart?.(m);
    }
  }

  @action
  onEndDateChange(event) {
    if (!event.target.value) {
      this.args.onUpdateEnd?.(null);
      return;
    }
    const startDateStr = this.formattedStartDate;
    const dateStr =
      startDateStr && event.target.value < startDateStr
        ? startDateStr
        : event.target.value;
    if (this.args.allDay && dateStr === startDateStr) {
      this.args.onUpdateEnd?.(null);
      return;
    }
    this.args.onUpdateEnd?.(
      this.combineDateTime(dateStr, this.endTimeForDate())
    );
  }

  @action
  onEndTimeChange(event) {
    if (!this.formattedEndDate) {
      return;
    }
    this.args.onUpdateEnd?.(
      this.combineDateTime(this.formattedEndDate, event.target.value || "00:00")
    );
  }

  @action
  toggleAllDay() {
    this.args.onUpdateAllDay?.(!this.args.allDay);
  }

  get rsvpsDisabled() {
    return this.args.status === "standalone";
  }

  get maxAttendeesPlaceholder() {
    if (this.rsvpsDisabled) {
      return "";
    }
    return i18n("discourse_post_event.composer.max_attendees_placeholder");
  }

  get displayMaxAttendees() {
    if (this._maxAttendeesOverride !== undefined) {
      return this._maxAttendeesOverride;
    }
    return this.args.maxAttendees ?? "";
  }

  @action
  onMaxAttendeesInput(event) {
    const raw = event.target.value;
    this._maxAttendeesOverride = raw;

    if (raw === "") {
      this.args.onUpdateMaxAttendees?.(null);
      return;
    }
    const parsed = parseInt(raw, 10);
    if (!Number.isFinite(parsed) || parsed < 0) {
      this._maxAttendeesOverride = "";
      event.target.value = "";
      this.args.onUpdateMaxAttendees?.(null);
      return;
    }
    if (parsed === 0) {
      // keep "0" visible while focused and submit on blur
      return;
    }
    this.args.onUpdateMaxAttendees?.(parsed);
  }

  @action
  onMaxAttendeesBlur(event) {
    const raw = event.target.value;
    this._maxAttendeesOverride = undefined;
    if (raw === "") {
      return;
    }
    const parsed = parseInt(raw, 10);
    if (parsed === 0) {
      this.args.onUpdateMaxAttendees?.(0);
    }
  }

  get notificationReminders() {
    return (this.args.reminders || [])
      .map((reminder, index) =>
        reminder.type === "notification"
          ? { reminder, index, label: this.#unitLabel(reminder) }
          : null
      )
      .filter(Boolean);
  }

  #unitLabel(reminder) {
    const unit = reminder.unit || "minutes";
    const count = parseInt(reminder.value, 10) || 0;
    const unitLabel = i18n(
      `discourse_post_event.composer.reminder.units.${unit}`,
      { count }
    );
    return i18n(
      `discourse_post_event.composer.reminder.${reminder.period || "before"}`,
      { unit: unitLabel }
    );
  }

  @action
  onReminderValueInput(index, event) {
    const parsed = parseInt(event.target.value, 10);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return;
    }
    const reminders = this.args.reminders || [];
    if (!reminders[index] || reminders[index].type !== "notification") {
      return;
    }
    const updated = reminders.map((r, i) =>
      i === index ? { ...r, value: parsed } : r
    );
    this.args.onUpdateReminders?.(updated);
  }

  @action
  removeReminder(index) {
    const reminders = this.args.reminders || [];
    if (!reminders[index] || reminders[index].type !== "notification") {
      return;
    }
    const updated = reminders.filter((_, i) => i !== index);
    this.args.onUpdateReminders?.(updated);
  }

  @action
  focusDateInput(event) {
    next(() => event.target.showPicker?.());
  }

  @action
  handleTextInputFocus(event) {
    if (this.capabilities.isIOS) {
      setTimeout(() => {
        event.target.scrollIntoView({ block: "center", behavior: "smooth" });
      }, 400);
    }
  }

  <template>
    <header class="composer-event__header">
      <div class="composer-event__date">
        <div class="composer-event__month">{{this.startsAtMonth}}</div>
        <div class="composer-event__day">{{this.startsAtDay}}</div>
      </div>

      <div class="composer-event__info">
        <DExpandingTextArea
          rows="1"
          value={{@name}}
          class="composer-event__name-input"
          placeholder={{@namePlaceholder}}
          {{on "input" this.onNameInput}}
          {{on "focus" this.handleTextInputFocus}}
        />

        <div class="composer-event__status">
          {{@statusText}}
        </div>
      </div>

      {{#if @onOpenAdvanced}}
        <div class="composer-event__more-dropdown">
          <DButton
            @icon="gear"
            @action={{@onOpenAdvanced}}
            @title="discourse_post_event.edit_event"
            class="btn-flat"
          />
        </div>
      {{/if}}
    </header>

    <section class="composer-event__dates">
      {{dIcon "clock"}}
      <div
        class={{dConcatClass
          "composer-event__date-range"
          (unless @allDay "composer-event__date-range--has-time")
        }}
      >
        <div class="composer-event__all-day-toggle">
          <DToggleSwitch
            class="composer-event__all-day-switch"
            @state={{@allDay}}
            @label="discourse_post_event.composer.all_day"
            {{on "click" this.toggleAllDay}}
          />
        </div>

        <div
          class={{dConcatClass
            "composer-event__date-row"
            (if this.showEndDateRow (unless @allDay "--multi-day"))
          }}
        >
          <div class="composer-event__date-wrapper">
            <input
              type="date"
              value={{this.formattedStartDate}}
              class="composer-event__date-input"
              {{on "change" this.onStartDateChange}}
              {{on "focus" this.focusDateInput}}
            />
            <span class="composer-event__date-display">
              {{this.formattedStartDisplay}}
            </span>
          </div>
          {{#unless @allDay}}
            <input
              type="time"
              value={{this.formattedStartTime}}
              class="composer-event__time-input"
              {{on "change" this.onStartTimeChange}}
            />
          {{/unless}}
          {{#if this.showInlineEndTime}}
            {{dIcon "arrow-right" class="composer-event__date-arrow"}}
            <input
              type="time"
              value={{this.formattedEndTime}}
              class="composer-event__time-input"
              {{on "change" this.onEndTimeChange}}
            />
          {{/if}}
        </div>

        {{#if this.showEndDateRow}}
          {{#if @allDay}}
            {{dIcon "arrow-right" class="composer-event__date-arrow"}}
          {{/if}}
          <div
            class={{dConcatClass
              "composer-event__date-row"
              (unless @allDay "--multi-day")
            }}
          >
            <div class="composer-event__date-wrapper">
              <input
                type="date"
                value={{this.formattedEndDate}}
                class="composer-event__date-input"
                {{on "change" this.onEndDateChange}}
                {{on "focus" this.focusDateInput}}
              />
              <span
                class={{dConcatClass
                  "composer-event__date-display"
                  (unless this.hasEndDate "--empty")
                }}
              >
                {{this.formattedEndDisplay}}
              </span>
            </div>
            {{#unless @allDay}}
              <input
                type="time"
                value={{this.formattedEndTime}}
                class="composer-event__time-input"
                {{on "change" this.onEndTimeChange}}
              />
            {{/unless}}
          </div>
        {{/if}}
      </div>
    </section>

    <section class="composer-event__location">
      {{dIcon this.locationIcon}}
      <div class="composer-event__location-content">
        <input
          type="text"
          value={{@location}}
          class="composer-event__location-input"
          placeholder={{i18n
            "discourse_post_event.composer.location_placeholder"
          }}
          {{on "input" this.onLocationInput}}
          {{on "focus" this.handleTextInputFocus}}
        />
        {{#if this.isLocationUrl}}
          <a
            class="composer-event__location-external-link"
            href={{this.displayLocation}}
            target="_blank"
            rel="noopener noreferrer"
            title="Visit {{@location}}"
          >
            {{dIcon "up-right-from-square"}}
          </a>
        {{/if}}
      </div>
    </section>

    <section class="composer-event__attendees">
      {{dIcon "users"}}
      <input
        type="number"
        inputmode="numeric"
        min="0"
        step="1"
        value={{this.displayMaxAttendees}}
        placeholder={{this.maxAttendeesPlaceholder}}
        class="composer-event__max-attendees-input"
        {{on "input" this.onMaxAttendeesInput}}
        {{on "blur" this.onMaxAttendeesBlur}}
      />
      {{#if this.rsvpsDisabled}}
        <span class="composer-event__max-attendees-display">
          {{i18n "discourse_post_event.composer.no_rsvps_label"}}
        </span>
      {{else if @maxAttendees}}
        <span class="composer-event__max-attendees-display">
          Max
          {{@maxAttendees}}
          attendees
        </span>
      {{/if}}
    </section>

    {{#each this.notificationReminders as |entry|}}
      <section class="composer-event__reminder">
        {{dIcon "bell"}}
        <input
          type="number"
          inputmode="numeric"
          min="1"
          step="1"
          value={{entry.reminder.value}}
          class="composer-event__reminder-value"
          {{on "input" (fn this.onReminderValueInput entry.index)}}
        />
        <span class="composer-event__reminder-unit">
          {{entry.label}}
        </span>
        <DButton
          @icon="xmark"
          @action={{fn this.removeReminder entry.index}}
          @title="discourse_post_event.composer.reminder.remove"
          class="btn-flat composer-event__reminder-remove"
        />
      </section>
    {{/each}}

    <section class="composer-event__description">
      <DExpandingTextArea
        class="composer-event__description-textarea"
        placeholder={{i18n
          "discourse_post_event.composer.description_placeholder"
        }}
        value={{@description}}
        rows="1"
        {{on "input" this.onDescriptionInput}}
        {{on "focus" this.handleTextInputFocus}}
      />
    </section>
  </template>
}
