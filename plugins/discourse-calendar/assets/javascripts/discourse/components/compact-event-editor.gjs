import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import DButton from "discourse/ui-kit/d-button";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PostEventBuilder from "discourse/plugins/discourse-calendar/discourse/components/modal/post-event-builder";
import {
  defaultEventState,
  isLivestreamUrl,
  reconcileDefaultReminder,
} from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";

export default class CompactEventEditor extends Component {
  @service capabilities;
  @service composer;
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked name;
  @tracked location;
  @tracked description;
  @tracked startsAt;
  @tracked endsAt;
  @tracked allDay;
  @tracked maxAttendees;
  @tracked status;
  @tracked timezone;
  @tracked reminders;
  @tracked recurrence;
  @tracked recurrenceUntil;
  @tracked showLocalTime;
  @tracked chatEnabled;
  @tracked livestream;
  @tracked minimal;
  @tracked url;
  @tracked image;
  @tracked allowedGroups;
  @tracked closed;
  @tracked customFields;
  #previousRsvpStatus = "public";
  #lastInitialStateRef;
  @tracked _maxAttendeesOverride;

  constructor() {
    super(...arguments);
    this.#syncFromInitialState();
  }

  @action
  syncIfStateChanged() {
    if (this.args.initialState !== this.#lastInitialStateRef) {
      this.#syncFromInitialState();
    }
  }

  #syncFromInitialState() {
    const s = { ...defaultEventState(), ...(this.args.initialState || {}) };
    this.name = s.name;
    this.location = s.location;
    this.description = s.description;
    this.startsAt = s.startsAt;
    this.endsAt = s.endsAt;
    this.allDay = s.allDay;
    this.maxAttendees = s.maxAttendees;
    this.status = s.status;
    this.timezone = s.timezone;
    this.reminders = s.reminders;
    this.recurrence = s.recurrence;
    this.recurrenceUntil = s.recurrenceUntil;
    this.showLocalTime = s.showLocalTime;
    this.chatEnabled = s.chatEnabled;
    this.livestream = s.livestream;
    this.minimal = s.minimal;
    this.url = s.url;
    this.image = s.image;
    this.allowedGroups = s.allowedGroups;
    this.closed = s.closed;
    this.customFields = { ...s.customFields };

    if (this.status && this.status !== "standalone") {
      this.#previousRsvpStatus = this.status;
    }
    this.#lastInitialStateRef = this.args.initialState;
  }

  get currentState() {
    return {
      name: this.name,
      location: this.location,
      description: this.description,
      startsAt: this.startsAt,
      endsAt: this.endsAt,
      allDay: this.allDay,
      maxAttendees: this.maxAttendees,
      status: this.status,
      timezone: this.timezone,
      reminders: this.reminders,
      recurrence: this.recurrence,
      recurrenceUntil: this.recurrenceUntil,
      showLocalTime: this.showLocalTime,
      chatEnabled: this.chatEnabled,
      livestream: this.livestream,
      minimal: this.minimal,
      url: this.url,
      image: this.image,
      allowedGroups: this.allowedGroups,
      closed: this.closed,
      customFields: this.customFields,
    };
  }

  #emitChange() {
    this.args.onChange?.(this.currentState);
  }

  #configSnapshot(overrides = {}) {
    return {
      startsAt: overrides.startsAt ?? this.startsAt,
      endsAt: overrides.endsAt ?? this.endsAt,
      allDay: overrides.allDay ?? this.allDay,
    };
  }

  get displayTime() {
    if (!this.startsAt) {
      return null;
    }
    return this.showLocalTime
      ? this.startsAt.clone()
      : this.startsAt.clone().tz(this.userTimezone);
  }

  get displayEndTime() {
    if (!this.endsAt) {
      return null;
    }
    return this.showLocalTime
      ? this.endsAt.clone()
      : this.endsAt.clone().tz(this.userTimezone);
  }

  get hasEndDate() {
    return !!this.endsAt;
  }

  get isMultiDay() {
    const start = this.formattedStartDate;
    const end = this.formattedEndDate;
    return !!start && !!end && start !== end;
  }

  get showInlineEndTime() {
    return !this.allDay && !this.isMultiDay;
  }

  get showEndDateRow() {
    return this.allDay || this.isMultiDay;
  }

  get formattedStartDisplay() {
    return this.displayTime
      ? this.displayTime.format(i18n("dates.long_no_year_no_time"))
      : "";
  }

  get formattedEndDisplay() {
    return this.displayEndTime
      ? this.displayEndTime.format(i18n("dates.long_no_year_no_time"))
      : i18n("discourse_post_event.composer.end_date_placeholder");
  }

  get startsAtMonth() {
    const m = this.displayTime || moment.tz(this.userTimezone);
    return m.format("MMM");
  }

  get startsAtDay() {
    const m = this.displayTime || moment.tz(this.userTimezone);
    return m.format("D");
  }

  get hasLocation() {
    return this.location && this.location.trim();
  }

  get isLocationUrl() {
    if (!this.hasLocation) {
      return false;
    }
    return this.args.urlTester?.(this.location) ?? false;
  }

  get isLivestreamUrl() {
    return this.hasLocation && isLivestreamUrl(this.location);
  }

  get locationIcon() {
    return this.isLocationUrl ? "link" : "location-pin";
  }

  get displayLocation() {
    if (!this.hasLocation) {
      return null;
    }
    if (this.isLocationUrl) {
      const location = this.location.trim();
      return location.includes("://") || location.includes("mailto:")
        ? location
        : `https://${location}`;
    }
    return this.location;
  }

  get statusText() {
    const status =
      this.status === "standalone" ? "public" : this.status || "public";
    return i18n(`discourse_post_event.models.event.status.${status}.title`);
  }

  get eventNamePlaceholder() {
    return (
      this.args.namePlaceholder ||
      this.composer?.get("model.title") ||
      i18n("discourse_post_event.composer.name_placeholder")
    );
  }

  get userTimezone() {
    return this.currentUser?.user_option?.timezone || moment.tz.guess();
  }

  #formatDate(m) {
    if (!m || typeof m.isValid !== "function" || !m.isValid()) {
      return "";
    }
    return m.format("YYYY-MM-DD");
  }

  #formatTime(m) {
    if (!m || typeof m.isValid !== "function" || !m.isValid()) {
      return "";
    }
    return m.format("HH:mm");
  }

  get formattedStartDate() {
    return this.#formatDate(this.startsAt);
  }

  get formattedEndDate() {
    return this.#formatDate(this.endsAt);
  }

  get formattedStartTime() {
    return this.#formatTime(this.startsAt);
  }

  get formattedEndTime() {
    return this.#formatTime(this.endsAt);
  }

  #combineDateTime(dateStr, timeStr) {
    const date = (dateStr || "").trim();
    if (!date) {
      return null;
    }
    const time = (timeStr || "").trim();
    return moment.tz(time ? `${date} ${time}` : date, this.timezone);
  }

  #startTimeForDate() {
    return this.allDay ? "" : this.formattedStartTime || "00:00";
  }

  #endTimeForDate() {
    return this.allDay ? "" : this.formattedEndTime || "00:00";
  }

  #reconcileReminders(oldConfig, newConfig) {
    this.reminders = reconcileDefaultReminder(
      this.reminders,
      oldConfig,
      newConfig
    );
  }

  @action
  onNameInput(event) {
    event.target.value = event.target.value.replace(/\n/g, "");
    this.name = event.target.value;
    this.#emitChange();
  }

  @action
  onLocationInput(event) {
    const value = event.target.value;
    this.location = value === "" ? null : value;
    if (!this.isLivestreamUrl) {
      this.livestream = false;
    }
    this.#emitChange();
  }

  get livestreamDisabled() {
    return !this.siteSettings.chat_enabled;
  }

  @action
  toggleLivestream() {
    if (this.livestreamDisabled) {
      return;
    }
    this.livestream = !this.livestream;
    this.#emitChange();
  }

  @action
  onDescriptionInput(event) {
    this.description = event.target.value;
    this.#emitChange();
  }

  @action
  onStartDateChange(event) {
    const dateStr = event.target.value;
    const newStart = this.#combineDateTime(dateStr, this.#startTimeForDate());
    if (!newStart) {
      return;
    }
    const oldConfig = this.#configSnapshot();
    this.startsAt = newStart;

    if (this.showInlineEndTime) {
      this.endsAt = this.#combineDateTime(dateStr, this.#endTimeForDate());
    } else {
      const endDateStr = this.formattedEndDate;
      if (endDateStr && dateStr > endDateStr) {
        this.endsAt = this.#combineDateTime(dateStr, this.#endTimeForDate());
      }
    }

    this.#reconcileReminders(oldConfig, this.#configSnapshot());
    this.#emitChange();
  }

  @action
  onStartTimeChange(event) {
    const newStart = this.#combineDateTime(
      this.formattedStartDate,
      event.target.value || "00:00"
    );
    if (!newStart) {
      return;
    }
    const oldConfig = this.#configSnapshot();
    this.startsAt = newStart;
    this.#reconcileReminders(oldConfig, this.#configSnapshot());
    this.#emitChange();
  }

  @action
  onEndDateChange(event) {
    const oldConfig = this.#configSnapshot();
    if (!event.target.value) {
      this.endsAt = null;
      this.#reconcileReminders(oldConfig, this.#configSnapshot());
      this.#emitChange();
      return;
    }
    const startDateStr = this.formattedStartDate;
    const dateStr =
      startDateStr && event.target.value < startDateStr
        ? startDateStr
        : event.target.value;
    if (this.allDay && dateStr === startDateStr) {
      this.endsAt = null;
    } else {
      this.endsAt = this.#combineDateTime(dateStr, this.#endTimeForDate());
    }
    this.#reconcileReminders(oldConfig, this.#configSnapshot());
    this.#emitChange();
  }

  @action
  onEndTimeChange(event) {
    if (!this.formattedEndDate) {
      return;
    }
    const oldConfig = this.#configSnapshot();
    this.endsAt = this.#combineDateTime(
      this.formattedEndDate,
      event.target.value || "00:00"
    );
    this.#reconcileReminders(oldConfig, this.#configSnapshot());
    this.#emitChange();
  }

  @action
  toggleAllDay() {
    const newAllDay = !this.allDay;
    const oldConfig = this.#configSnapshot();

    if (newAllDay) {
      const startDate = (this.startsAt || moment.tz(this.timezone)).format(
        "YYYY-MM-DD"
      );
      const existingEnd = this.endsAt;
      this.startsAt = moment.tz(startDate, this.timezone);

      if (existingEnd) {
        const endDate = existingEnd.format("YYYY-MM-DD");
        this.endsAt =
          endDate === startDate ? null : moment.tz(endDate, this.timezone);
      } else {
        this.endsAt = null;
      }
    } else if (this.startsAt) {
      const nowTime = moment.tz(this.timezone);
      const newStart = this.startsAt
        .clone()
        .hour(nowTime.hour())
        .minute(nowTime.minute())
        .second(0)
        .millisecond(0);
      this.startsAt = newStart;
      this.endsAt = newStart.clone().add(1, "hour");
    }
    this.allDay = newAllDay;
    this.#reconcileReminders(oldConfig, this.#configSnapshot());
    this.#emitChange();
  }

  get rsvpsDisabled() {
    return this.status === "standalone";
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
    return this.maxAttendees ?? "";
  }

  #applyMaxAttendees(value) {
    if (value === 0) {
      if (this.status && this.status !== "standalone") {
        this.#previousRsvpStatus = this.status;
      }
      this.status = "standalone";
      this.maxAttendees = null;
      this.reminders = this.reminders.map((r) =>
        r.type === "notification" ? { ...r, type: "bumpTopic" } : r
      );
    } else if (this.status === "standalone" && value > 0) {
      this.status = this.#previousRsvpStatus || "public";
      this.maxAttendees = value;
      this.reminders = this.reminders.map((r) =>
        r.type === "bumpTopic" ? { ...r, type: "notification" } : r
      );
    } else {
      this.maxAttendees = value;
    }
    this.#emitChange();
  }

  @action
  onMaxAttendeesInput(event) {
    const raw = event.target.value;
    this._maxAttendeesOverride = raw;

    if (raw === "") {
      this.#applyMaxAttendees(null);
      return;
    }
    const parsed = parseInt(raw, 10);
    if (!Number.isFinite(parsed) || parsed < 0) {
      this._maxAttendeesOverride = "";
      event.target.value = "";
      this.#applyMaxAttendees(null);
      return;
    }
    if (parsed === 0) {
      return;
    }
    this.#applyMaxAttendees(parsed);
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
      this.#applyMaxAttendees(0);
    }
  }

  get visibleReminders() {
    return (this.reminders || []).map((reminder, index) => {
      const isBump = reminder.type === "bumpTopic";
      return {
        reminder,
        index,
        label: this.#unitLabel(reminder),
        icon: isBump ? "arrows-up-to-line" : "bell",
        iconTitle: isBump
          ? "discourse_post_event.composer.reminder.bump_topic_title"
          : "discourse_post_event.composer.reminder.notification_title",
      };
    });
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
    if (!this.reminders[index]) {
      return;
    }
    this.reminders = this.reminders.map((r, i) =>
      i === index ? { ...r, value: parsed } : r
    );
    this.#emitChange();
  }

  @action
  removeReminder(index) {
    if (!this.reminders[index]) {
      return;
    }
    this.reminders = this.reminders.filter((_, i) => i !== index);
    this.#emitChange();
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

  @action
  openAdvanced() {
    const event = DiscoursePostEventEvent.create({
      name: this.name,
      location: this.location,
      description: this.description,
      timezone: this.timezone,
      status: this.status,
      max_attendees: this.maxAttendees,
      show_local_time: this.showLocalTime,
      chat_enabled: this.chatEnabled,
      livestream: this.livestream,
      minimal: this.minimal,
      all_day: this.allDay,
      reminders: this.reminders,
      raw_invitees: this.allowedGroups?.split(",") || [],
      custom_fields: { ...this.customFields },
      starts_at: this.startsAt,
      ends_at: this.endsAt,
      url: this.url,
      recurrence: this.recurrence,
      recurrence_until: this.recurrenceUntil,
      image_upload: this.image ? { url: this.image } : null,
    });

    this.modal.show(PostEventBuilder, {
      model: {
        event,
        initialScreen: "advanced",
        onDelete: () => {
          this.args.onDelete?.();
          return true;
        },
        onUpdate: (startsAt, endsAt, updatedEvent) => {
          this.startsAt = startsAt;
          this.endsAt = endsAt;
          this.name = updatedEvent.name || null;
          this.location = updatedEvent.location || null;
          this.description = updatedEvent.description || "";
          this.timezone = updatedEvent.timezone || this.timezone;
          this.status = updatedEvent.status || "public";
          this.maxAttendees = updatedEvent.maxAttendees ?? null;
          this.showLocalTime = !!updatedEvent.showLocalTime;
          this.chatEnabled = !!updatedEvent.chatEnabled;
          this.livestream = !!updatedEvent.livestream;
          this.minimal = !!updatedEvent.minimal;
          this.allDay = !!updatedEvent.allDay;
          this.reminders = updatedEvent.reminders || [];
          this.recurrence = updatedEvent.recurrence || null;
          this.recurrenceUntil = updatedEvent.recurrenceUntil || null;
          this.url = updatedEvent.url || null;
          this.allowedGroups =
            (updatedEvent.rawInvitees || []).join(",") || null;
          this.image = updatedEvent.imageUpload?.short_url
            ? updatedEvent.imageUpload.short_url
            : updatedEvent.imageUpload?.url || null;
          this.customFields = { ...(updatedEvent.customFields || {}) };

          if (this.status && this.status !== "standalone") {
            this.#previousRsvpStatus = this.status;
          }

          this.#emitChange();
          // Modal-driven updates are discrete commits, not interim keystrokes.
          // Tell the wrapper to flush immediately rather than wait for blur,
          // since focus returns to the gear button (inside the wrapper).
          this.args.onCommit?.();
        },
      },
    });
  }

  <template>
    <header
      class="composer-event__header"
      {{didUpdate this.syncIfStateChanged @initialState}}
    >
      <div class="composer-event__date">
        <div class="composer-event__month">{{this.startsAtMonth}}</div>
        <div class="composer-event__day">{{this.startsAtDay}}</div>
      </div>

      <div class="composer-event__info">
        <DExpandingTextArea
          rows="1"
          value={{this.name}}
          class="composer-event__name-input"
          placeholder={{this.eventNamePlaceholder}}
          {{on "input" this.onNameInput}}
          {{on "focus" this.handleTextInputFocus}}
        />

        <div class="composer-event__status">
          {{this.statusText}}
        </div>
      </div>

      {{#unless @hideAdvanced}}
        <div class="composer-event__more-dropdown">
          <DButton
            @icon="gear"
            @action={{this.openAdvanced}}
            @title="discourse_post_event.edit_event"
            class="btn-flat"
          />
        </div>
      {{/unless}}
    </header>

    <section class="composer-event__dates">
      {{dIcon "clock"}}
      <div
        class={{dConcatClass
          "composer-event__date-range"
          (unless this.allDay "composer-event__date-range--has-time")
        }}
      >
        <div class="composer-event__all-day-toggle">
          <DToggleSwitch
            class="composer-event__all-day-switch"
            @state={{this.allDay}}
            @label="discourse_post_event.composer.all_day"
            {{on "click" this.toggleAllDay}}
          />
        </div>

        <div
          class={{dConcatClass
            "composer-event__date-row"
            (if this.showEndDateRow (unless this.allDay "--multi-day"))
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
          {{#unless this.allDay}}
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
          {{#if this.allDay}}
            {{dIcon "arrow-right" class="composer-event__date-arrow"}}
          {{/if}}
          <div
            class={{dConcatClass
              "composer-event__date-row"
              (unless this.allDay "--multi-day")
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
            {{#unless this.allDay}}
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
          value={{this.location}}
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
            title="Visit {{this.location}}"
          >
            {{dIcon "up-right-from-square"}}
          </a>
        {{/if}}
      </div>
    </section>

    {{#if this.isLivestreamUrl}}
      <section class="composer-event__livestream">
        {{#if this.livestreamDisabled}}
          <DTooltip
            @placement="top-start"
            class="composer-event__livestream-toggle"
          >
            <:trigger>
              <DToggleSwitch
                class="composer-event__livestream-switch"
                @state={{this.livestream}}
                @label="discourse_post_event.composer.livestream"
                disabled
              />
            </:trigger>
            <:content>
              {{i18n "discourse_post_event.composer.livestream_chat_disabled"}}
            </:content>
          </DTooltip>
        {{else}}
          <div class="composer-event__livestream-toggle">
            <DToggleSwitch
              class="composer-event__livestream-switch"
              @state={{this.livestream}}
              @label="discourse_post_event.composer.livestream"
              {{on "click" this.toggleLivestream}}
            />
          </div>
        {{/if}}
      </section>
    {{/if}}

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
      {{else if this.maxAttendees}}
        <span class="composer-event__max-attendees-display">
          {{i18n
            "discourse_post_event.composer.max_attendees_display"
            count=this.maxAttendees
          }}
        </span>
      {{/if}}
    </section>

    {{#each this.visibleReminders as |entry|}}
      <section class="composer-event__reminder">
        <DTooltip class="composer-event__reminder-icon">
          <:trigger>{{dIcon entry.icon}}</:trigger>
          <:content>{{i18n entry.iconTitle}}</:content>
        </DTooltip>
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
        value={{this.description}}
        rows="1"
        {{on "input" this.onDescriptionInput}}
        {{on "focus" this.handleTextInputFocus}}
      />
    </section>

    <PluginOutlet
      @name="discourse-post-event-composer-editor"
      @outletArgs={{lazyHash editor=this}}
    />
  </template>
}
