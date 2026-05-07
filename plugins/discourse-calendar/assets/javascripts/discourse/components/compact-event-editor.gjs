import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import ExpandingTextArea from "discourse/components/expanding-text-area";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CompactEventEditor extends Component {
  @service capabilities;

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

  @action
  onMaxAttendeesInput(event) {
    const newMax = parseInt(event.target.value, 10);
    const validMax = Number.isFinite(newMax) && newMax > 0 ? newMax : null;
    event.target.value = validMax || "";
    this.args.onUpdateMaxAttendees?.(validMax);
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
        <ExpandingTextArea
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
      {{icon "clock"}}
      <div
        class={{concatClass
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

        <div class="composer-event__date-row">
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
        </div>

        <div class="composer-event__date-row">
          <div class="composer-event__date-wrapper">
            <input
              type="date"
              value={{this.formattedEndDate}}
              class="composer-event__date-input"
              {{on "change" this.onEndDateChange}}
              {{on "focus" this.focusDateInput}}
            />
            <span
              class={{concatClass
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
      </div>
    </section>

    <section class="composer-event__location">
      {{icon this.locationIcon}}
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
            {{icon "up-right-from-square"}}
          </a>
        {{/if}}
      </div>
    </section>

    <section class="composer-event__attendees">
      {{icon "users"}}
      <input
        type="number"
        inputmode="numeric"
        min="1"
        step="1"
        value={{@maxAttendees}}
        placeholder={{i18n
          "discourse_post_event.composer.max_attendees_placeholder"
        }}
        class="composer-event__max-attendees-input"
        {{on "input" this.onMaxAttendeesInput}}
      />
      {{#if @maxAttendees}}
        <span class="composer-event__max-attendees-display">
          Max
          {{@maxAttendees}}
          attendees
        </span>
      {{/if}}
    </section>

    <section class="composer-event__description">
      <ExpandingTextArea
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
