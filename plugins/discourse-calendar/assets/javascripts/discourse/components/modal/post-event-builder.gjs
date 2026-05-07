/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DateInput from "discourse/components/date-input";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import GroupSelector from "discourse/components/group-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import RadioButton from "discourse/components/radio-button";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import lazyHash from "discourse/helpers/lazy-hash";
import { extractError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import ComboBox from "discourse/select-kit/components/combo-box";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import { eq, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { buildParams } from "../../lib/raw-event-helper";
import CompactEventEditor from "../compact-event-editor";
import EventField from "../event-field";

export default class PostEventBuilder extends Component {
  @service dialog;
  @service siteSettings;
  @service currentUser;

  @tracked flash = null;
  @tracked isSaving = false;
  @tracked maxAttendeesInput = this.args.model.event.maxAttendees;
  @tracked screen = this.args.model.initialScreen || "compact";

  @tracked allDay = this.event.allDay || false;
  @tracked startsAt = this.#initStartsAt();
  @tracked endsAt = this.#initEndsAt();
  @tracked
  previousRsvpStatus =
    this.event.status === "standalone" ? "public" : this.event.status;

  #initStartsAt() {
    if (this.event.allDay) {
      return moment(this.event.startsAt, "YYYY-MM-DD");
    }
    return moment(this.event.startsAt).tz(this.event.timezone || "UTC");
  }

  #initEndsAt() {
    if (!this.event.endsAt) {
      return null;
    }
    if (this.event.allDay) {
      return moment(this.event.endsAt, "YYYY-MM-DD");
    }
    return moment(this.event.endsAt).tz(this.event.timezone || "UTC");
  }

  get showTime() {
    return !this.allDay;
  }

  get isEditing() {
    return this.args.model.event.id || this.args.model.onUpdate;
  }

  get recurrenceUntil() {
    return (
      this.event.recurrenceUntil &&
      moment(this.event.recurrenceUntil).tz(this.event.timezone || "UTC")
    );
  }

  get event() {
    return this.args.model.event;
  }

  get reminderTypes() {
    const types = [
      {
        value: "notification",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.types.notification"
        ),
      },
      {
        value: "bumpTopic",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.types.bump_topic"
        ),
      },
    ];
    return this.allowsRsvps
      ? types
      : types.filter((t) => t.value !== "notification");
  }

  get reminderUnits() {
    return [
      {
        value: "minutes",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.units.minutes"
        ),
      },
      {
        value: "hours",
        name: i18n("discourse_post_event.builder_modal.reminders.units.hours"),
      },
      {
        value: "days",
        name: i18n("discourse_post_event.builder_modal.reminders.units.days"),
      },
      {
        value: "weeks",
        name: i18n("discourse_post_event.builder_modal.reminders.units.weeks"),
      },
    ];
  }

  get reminderPeriods() {
    return [
      {
        value: "before",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.periods.before"
        ),
      },
      {
        value: "after",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.periods.after"
        ),
      },
    ];
  }

  get shouldRenderUrl() {
    return this.args.model.event.url !== undefined;
  }

  get availableRecurrences() {
    const ref = this.startsAt || moment();
    const weekday = ref.format("dddd");
    const dayOfMonth = ref.date();
    const isLast = dayOfMonth + 7 > ref.daysInMonth();
    const ordinalKey = isLast
      ? "last"
      : ["first", "second", "third", "fourth"][Math.ceil(dayOfMonth / 7) - 1];
    const ordinal = i18n(
      `discourse_post_event.builder_modal.recurrence.ordinals.${ordinalKey}`
    );

    return [
      {
        id: "every_day",
        name: i18n("discourse_post_event.builder_modal.recurrence.every_day"),
      },
      {
        id: "every_weekday",
        name: i18n(
          "discourse_post_event.builder_modal.recurrence.every_weekday"
        ),
      },
      {
        id: "every_week",
        name: i18n("discourse_post_event.builder_modal.recurrence.every_week", {
          weekday,
        }),
      },
      {
        id: "every_two_weeks",
        name: i18n(
          "discourse_post_event.builder_modal.recurrence.every_two_weeks",
          { weekday }
        ),
      },
      {
        id: "every_four_weeks",
        name: i18n(
          "discourse_post_event.builder_modal.recurrence.every_four_weeks",
          { weekday }
        ),
      },
      {
        id: "every_month",
        name: i18n(
          "discourse_post_event.builder_modal.recurrence.every_month",
          { ordinal, weekday }
        ),
      },
    ];
  }

  get allowedCustomFields() {
    return this.siteSettings.discourse_post_event_allowed_custom_fields
      .split("|")
      .filter(Boolean);
  }

  get addReminderDisabled() {
    return this.event.reminders?.length >= 5;
  }

  get showChat() {
    // As of June 2025, chat channel creation is only available to admins and moderators
    return (
      this.siteSettings.chat_enabled &&
      (this.currentUser.admin || this.currentUser.moderator)
    );
  }

  get isAdvancedScreen() {
    return this.screen === "advanced";
  }

  get showScreenToggle() {
    return this.args.model.initialScreen !== "advanced";
  }

  get userTimezone() {
    return this.currentUser?.user_option?.timezone || moment.tz.guess();
  }

  get statusText() {
    return i18n(
      `discourse_post_event.models.event.status.${this.event.status || "public"}.title`
    );
  }

  get eventNamePlaceholder() {
    return i18n("discourse_post_event.composer.name_placeholder");
  }

  @action
  toggleAdvanced() {
    this.screen = this.isAdvancedScreen ? "compact" : "advanced";
  }

  @action
  updateName(value) {
    this.event.name = value;
  }

  @action
  updateLocation(value) {
    this.event.location = value || "";
  }

  @action
  updateDescription(value) {
    this.event.description = value;
  }

  @action
  updateStart(newMoment) {
    if (!newMoment) {
      return;
    }
    const tz = this.event.timezone || "UTC";
    const m = newMoment.clone().tz(tz);
    this.event.startsAt = m;
    this.startsAt = m;
  }

  @action
  updateEnd(newMoment) {
    if (!newMoment) {
      this.event.endsAt = null;
      this.endsAt = null;
      return;
    }
    const tz = this.event.timezone || "UTC";
    const m = newMoment.clone().tz(tz);
    this.event.endsAt = m;
    this.endsAt = m;
  }

  @action
  updateAllDay(allDay) {
    this.allDay = allDay;
    this.event.allDay = allDay;
    if (allDay) {
      if (this.startsAt) {
        const snapped = this.startsAt.clone().startOf("day");
        this.startsAt = snapped;
        this.event.startsAt = snapped;
      }
      if (this.endsAt) {
        const snapped = this.endsAt.clone().endOf("day");
        this.endsAt = snapped;
        this.event.endsAt = snapped;
      }
      if (
        this.startsAt &&
        this.endsAt &&
        this.startsAt.isSame(this.endsAt, "day")
      ) {
        this.endsAt = null;
        this.event.endsAt = null;
      }
    } else if (this.startsAt) {
      const tz = this.event.timezone || "UTC";
      const nowTime = moment.tz(tz);
      const newStart = this.startsAt
        .clone()
        .hour(nowTime.hour())
        .minute(nowTime.minute())
        .second(0)
        .millisecond(0);
      this.startsAt = newStart;
      this.event.startsAt = newStart;

      const newEnd = newStart.clone().add(1, "hour");
      this.endsAt = newEnd;
      this.event.endsAt = newEnd;
    }
  }

  @action
  updateMaxAttendees(value) {
    this.event.maxAttendees = value;
    this.maxAttendeesInput = value || "";
  }

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  }

  @action
  setCustomField(field, e) {
    this.event.customFields[field] = e.target.value;
  }

  @action
  setMaxAttendees(e) {
    const raw = e.target.value;
    const value = parseInt(raw, 10);
    this.event.maxAttendees =
      Number.isFinite(value) && value > 0 ? value : null;
    this.maxAttendeesInput = raw;
  }

  @action
  onChangeDates(dates) {
    this.event.startsAt = dates.from;
    this.event.endsAt = dates.to;
    this.startsAt = dates.from;
    this.endsAt = dates.to;
  }

  @action
  setAllDay(e) {
    this.updateAllDay(e.target.checked);
  }

  get allowsRsvps() {
    return this.event.status !== "standalone";
  }

  @action
  addReminder() {
    this.event.addReminder({
      type: this.allowsRsvps ? "notification" : "bumpTopic",
      value: 15,
      unit: "minutes",
      period: "before",
    });
  }

  @action
  setAllowRsvps(e) {
    if (e.target.checked) {
      this.event.status = this.previousRsvpStatus || "public";
    } else {
      if (this.event.status && this.event.status !== "standalone") {
        this.previousRsvpStatus = this.event.status;
      }
      this.event.status = "standalone";
      this.event.reminders = (this.event.reminders || []).map((r) =>
        r.type === "notification" ? { ...r, type: "bumpTopic" } : r
      );
    }
  }

  @action
  onChangeStatus(newStatus) {
    this.event.rawInvitees = [];
    this.event.status = newStatus;
  }

  @action
  setRecurrence(newRecurrence) {
    if (!newRecurrence) {
      this.event.recurrence = null;
      this.event.recurrenceUntil = null;
      return;
    }

    this.event.recurrence = newRecurrence;
  }

  @action
  setRecurrenceUntil(until) {
    if (!until) {
      this.event.recurrenceUntil = null;
    } else {
      this.event.recurrenceUntil = moment(until).endOf("day").toDate();
    }
  }

  @action
  setRawInvitees(_, newInvitees) {
    this.event.rawInvitees = newInvitees;
  }

  @action
  setNewTimezone(newTz) {
    this.event.timezone = newTz;
    this.event.startsAt = moment.tz(
      this.startsAt.format("YYYY-MM-DDTHH:mm"),
      newTz
    );
    this.event.endsAt = this.endsAt
      ? moment.tz(this.endsAt.format("YYYY-MM-DDTHH:mm"), newTz)
      : null;
    this.startsAt = moment(this.event.startsAt).tz(newTz);
    this.endsAt = this.event.endsAt
      ? moment(this.event.endsAt).tz(newTz)
      : null;
  }

  // Native input handlers
  @action
  setName(e) {
    this.event.name = e.target.value;
  }

  @action
  setLocation(e) {
    this.event.location = e.target.value;
  }

  @action
  setUrl(e) {
    this.event.url = e.target.value;
  }

  @action
  setDescription(e) {
    this.event.description = e.target.value;
  }

  @action
  setShowLocalTime(e) {
    this.event.showLocalTime = e.target.checked;
  }

  @action
  setImage(upload) {
    this.event.imageUpload = upload;
  }

  @action
  removeImage() {
    this.event.imageUpload = null;
  }

  @action
  setChatEnabled(e) {
    this.event.chatEnabled = e.target.checked;
  }

  @action
  setReminderValue(reminder, e) {
    const val = e.target.value;
    // keep numeric when possible
    const parsed = val === "" ? null : Number(val);
    reminder.value = Number.isFinite(parsed) ? parsed : val;
  }

  @action
  async destroyPostEvent() {
    try {
      const confirmResult = await this.dialog.yesNoConfirm({
        message: i18n(
          "discourse_post_event.builder_modal.delete_confirmation_message"
        ),
      });

      if (confirmResult) {
        const result = await this.args.model.onDelete();
        if (result) {
          this.args.closeModal();
        }
      }
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  createEvent() {
    if (!this.startsAt) {
      this.args.closeModal();
      return;
    }

    const eventParams = buildParams(
      this.startsAt,
      this.endsAt,
      this.event,
      this.siteSettings
    );

    const description = eventParams.description
      ? `${eventParams.description}\n`
      : "";
    delete eventParams.description;

    const markdownParams = [];
    Object.keys(eventParams).forEach((key) => {
      let value = eventParams[key];
      markdownParams.push(`${key}="${value}"`);
    });

    this.args.model.toolbarEvent.addText(
      `[event ${markdownParams.join(" ")}]\n${description}[/event]`
    );
    this.args.closeModal();
  }

  @action
  async updateEvent() {
    try {
      this.isSaving = true;

      await this.args.model.onUpdate(
        this.startsAt,
        this.endsAt,
        this.event,
        this.siteSettings
      );

      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n
        (concat
          "discourse_post_event.builder_modal."
          (if
            this.isAdvancedScreen
            "advanced_settings_title"
            (if this.isEditing "update_event_title" "create_event_title")
          )
        )
      }}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      class="post-event-builder-modal
        {{if this.isAdvancedScreen 'is-advanced' 'is-compact'}}"
    >
      <:body>
        <ConditionalLoadingSection @isLoading={{this.isSaving}}>
          {{#if this.isAdvancedScreen}}
            <form>
              <PluginOutlet
                @name="post-event-builder-form"
                @outletArgs={{lazyHash event=@model.event}}
                @connectorTagName="div"
              >
                <EventField>
                  <DateTimeInputRange
                    @from={{this.startsAt}}
                    @to={{this.endsAt}}
                    @timezone={{@model.event.timezone}}
                    @onChange={{this.onChangeDates}}
                    @showFromTime={{this.showTime}}
                    @showToTime={{this.showTime}}
                  />
                </EventField>

                <EventField
                  @label="discourse_post_event.builder_modal.all_day.label"
                  class="all-day"
                >
                  <label class="checkbox-label">
                    <input
                      type="checkbox"
                      checked={{this.allDay}}
                      {{on "input" this.setAllDay}}
                    />
                    <span class="message">
                      {{i18n
                        "discourse_post_event.builder_modal.all_day.description"
                      }}
                    </span>
                  </label>
                </EventField>

                <EventField
                  @label="discourse_post_event.builder_modal.name.label"
                  class="name"
                >
                  <input
                    type="text"
                    value={{@model.event.name}}
                    {{on "input" this.setName}}
                    placeholder={{i18n
                      "discourse_post_event.builder_modal.name.placeholder"
                    }}
                  />
                </EventField>

                <EventField
                  @label="discourse_post_event.builder_modal.location.label"
                  class="location"
                >
                  <input
                    type="text"
                    value={{@model.event.location}}
                    {{on "input" this.setLocation}}
                    placeholder={{i18n
                      "discourse_post_event.builder_modal.location.placeholder"
                    }}
                  />
                </EventField>

                {{#if this.shouldRenderUrl}}
                  <EventField
                    @label="discourse_post_event.builder_modal.url.label"
                    class="url"
                  >
                    <input
                      type="url"
                      value={{@model.event.url}}
                      {{on "input" this.setUrl}}
                      placeholder={{i18n
                        "discourse_post_event.builder_modal.url.placeholder"
                      }}
                    />
                  </EventField>
                {{/if}}

                <EventField
                  @label="discourse_post_event.builder_modal.description.label"
                  class="description"
                >
                  <textarea
                    value={{@model.event.description}}
                    {{on "input" this.setDescription}}
                    placeholder={{i18n
                      "discourse_post_event.builder_modal.description.placeholder"
                    }}
                  ></textarea>
                </EventField>

                <EventField
                  class="allow-rsvps"
                  @label="discourse_post_event.builder_modal.allow_rsvps.label"
                >
                  <label class="checkbox-label">
                    <input
                      type="checkbox"
                      checked={{this.allowsRsvps}}
                      {{on "input" this.setAllowRsvps}}
                    />
                    <span class="message">
                      {{i18n
                        "discourse_post_event.builder_modal.allow_rsvps.description"
                      }}
                    </span>
                  </label>
                </EventField>

                <EventField
                  class="max-attendees"
                  @label="discourse_post_event.builder_modal.max_attendees.label"
                >
                  <input
                    type="number"
                    min="1"
                    step="1"
                    value={{this.maxAttendeesInput}}
                    disabled={{not this.allowsRsvps}}
                    {{on "input" this.setMaxAttendees}}
                    placeholder={{i18n
                      "discourse_post_event.builder_modal.max_attendees.placeholder"
                    }}
                  />
                </EventField>

                {{#if this.allowsRsvps}}
                  <EventField
                    @label="discourse_post_event.builder_modal.attendee_type.label"
                  >
                    <label class="radio-label">
                      <RadioButton
                        @name="status"
                        @value="public"
                        @selection={{@model.event.status}}
                        @onChange={{this.onChangeStatus}}
                      />
                      <span class="message">
                        <span class="title">
                          {{i18n
                            "discourse_post_event.models.event.status.public.title"
                          }}
                        </span>
                        <span class="description">
                          {{i18n
                            "discourse_post_event.models.event.status.public.description"
                          }}
                        </span>
                      </span>
                    </label>
                    <label class="radio-label">
                      <RadioButton
                        @name="status"
                        @value="private"
                        @selection={{@model.event.status}}
                        @onChange={{this.onChangeStatus}}
                      />
                      <span class="message">
                        <span class="title">
                          {{i18n
                            "discourse_post_event.models.event.status.private.title"
                          }}
                        </span>
                        <span class="description">
                          {{i18n
                            "discourse_post_event.models.event.status.private.description"
                          }}
                        </span>
                      </span>
                    </label>
                  </EventField>

                  <EventField
                    @enabled={{eq @model.event.status "private"}}
                    @label="discourse_post_event.builder_modal.invitees.label"
                  >
                    <GroupSelector
                      @groupFinder={{this.groupFinder}}
                      @groupNames={{@model.event.rawInvitees}}
                      @onChangeCallback={{this.setRawInvitees}}
                      @placeholderKey="topic.invite_private.group_name"
                    />
                  </EventField>
                {{/if}}

                <EventField
                  class="timezone"
                  @label="discourse_post_event.builder_modal.timezone.label"
                >
                  <TimezoneInput
                    @value={{@model.event.timezone}}
                    @onChange={{this.setNewTimezone}}
                    @none="discourse_post_event.builder_modal.timezone.remove_timezone"
                  />
                </EventField>

                <EventField
                  class="show-local-time"
                  @label="discourse_post_event.builder_modal.show_local_time.label"
                >
                  <label class="checkbox-label">
                    <input
                      type="checkbox"
                      checked={{@model.event.showLocalTime}}
                      {{on "input" this.setShowLocalTime}}
                    />
                    <span class="message">
                      {{i18n
                        "discourse_post_event.builder_modal.show_local_time.description"
                        timezone=@model.event.timezone
                      }}
                    </span>
                  </label>
                </EventField>

                <EventField
                  class="reminders"
                  @label="discourse_post_event.builder_modal.reminders.label"
                >
                  <div class="reminders-list">
                    {{#each @model.event.reminders as |reminder|}}
                      <div class="reminder-item">
                        <ComboBox
                          @value={{reminder.type}}
                          @nameProperty="name"
                          @valueProperty="value"
                          @content={{this.reminderTypes}}
                          class="reminder-type"
                        />

                        <input
                          type="number"
                          class="reminder-value"
                          min="0"
                          step="1"
                          value={{reminder.value}}
                          {{on "input" (fn this.setReminderValue reminder)}}
                          placeholder={{i18n
                            "discourse_post_event.builder_modal.name.placeholder"
                          }}
                        />

                        <ComboBox
                          @value={{reminder.unit}}
                          @nameProperty="name"
                          @valueProperty="value"
                          @content={{this.reminderUnits}}
                          class="reminder-unit"
                        />

                        <ComboBox
                          @value={{reminder.period}}
                          @nameProperty="name"
                          @valueProperty="value"
                          @content={{this.reminderPeriods}}
                          class="reminder-period"
                        />

                        <DButton
                          @action={{fn @model.event.removeReminder reminder}}
                          @icon="xmark"
                          class="btn-default remove-reminder"
                        />
                      </div>
                    {{/each}}
                  </div>

                  <DButton
                    @disabled={{this.addReminderDisabled}}
                    @icon="plus"
                    @label="discourse_post_event.builder_modal.add_reminder"
                    @action={{this.addReminder}}
                    class="btn-default add-reminder"
                  />
                </EventField>

                <EventField
                  class="recurrence"
                  @label="discourse_post_event.builder_modal.recurrence.label"
                >
                  <ComboBox
                    class="available-recurrences"
                    @value={{@model.event.recurrence}}
                    @content={{this.availableRecurrences}}
                    @onChange={{this.setRecurrence}}
                    @options={{lazyHash
                      none="discourse_post_event.builder_modal.recurrence.none"
                    }}
                  />
                </EventField>

                {{#if @model.event.recurrence}}
                  <EventField
                    @label="discourse_post_event.builder_modal.recurrence_until.label"
                    class="recurrence-until"
                  >
                    <DateInput
                      @date={{this.recurrenceUntil}}
                      @onChange={{this.setRecurrenceUntil}}
                      @timezone={{@model.event.timezone}}
                    />
                  </EventField>
                {{/if}}

                {{#if this.showChat}}
                  <EventField
                    class="allow-chat"
                    @label="discourse_post_event.builder_modal.allow_chat.label"
                  >
                    <label class="checkbox-label">
                      <input
                        type="checkbox"
                        checked={{@model.event.chatEnabled}}
                        {{on "input" this.setChatEnabled}}
                      />
                      <span class="message">
                        {{i18n
                          "discourse_post_event.builder_modal.allow_chat.checkbox_label"
                        }}
                      </span>
                    </label>
                  </EventField>
                {{/if}}

                {{#if this.allowedCustomFields.length}}
                  <EventField
                    @label="discourse_post_event.builder_modal.custom_fields.label"
                  >
                    <p class="event-field-description">
                      {{i18n
                        "discourse_post_event.builder_modal.custom_fields.description"
                      }}
                    </p>
                    {{#each this.allowedCustomFields as |allowedCustomField|}}
                      <span class="label custom-field-label">
                        {{allowedCustomField}}
                      </span>
                      <input
                        type="text"
                        class="custom-field-input"
                        value={{get
                          @model.event.customFields
                          allowedCustomField
                        }}
                        {{on
                          "input"
                          (fn this.setCustomField allowedCustomField)
                        }}
                        placeholder={{i18n
                          "discourse_post_event.builder_modal.custom_fields.placeholder"
                        }}
                      />
                    {{/each}}
                  </EventField>
                {{/if}}

                <EventField
                  @label="discourse_post_event.builder_modal.image.label"
                  class="image"
                >
                  <UppyImageUploader
                    @id="post-event-image-uploader"
                    @imageUrl={{this.event.imageUrl}}
                    @onUploadDone={{this.setImage}}
                    @onUploadDeleted={{this.removeImage}}
                    @type="event_image"
                  />
                </EventField>
              </PluginOutlet>
            </form>
          {{else}}
            <div class="composer-event-node">
              <CompactEventEditor
                @name={{@model.event.name}}
                @location={{@model.event.location}}
                @description={{@model.event.description}}
                @maxAttendees={{@model.event.maxAttendees}}
                @startsAt={{this.startsAt}}
                @endsAt={{this.endsAt}}
                @allDay={{this.allDay}}
                @timezone={{@model.event.timezone}}
                @userTimezone={{this.userTimezone}}
                @statusText={{this.statusText}}
                @namePlaceholder={{this.eventNamePlaceholder}}
                @onUpdateName={{this.updateName}}
                @onUpdateLocation={{this.updateLocation}}
                @onUpdateDescription={{this.updateDescription}}
                @onUpdateStart={{this.updateStart}}
                @onUpdateEnd={{this.updateEnd}}
                @onUpdateAllDay={{this.updateAllDay}}
                @onUpdateMaxAttendees={{this.updateMaxAttendees}}
              />
            </div>
          {{/if}}
        </ConditionalLoadingSection>
      </:body>
      <:footer>
        {{#if @model.onUpdate}}
          <DButton
            class="btn-primary"
            @label="discourse_post_event.builder_modal.update"
            @icon="calendar-day"
            @action={{this.updateEvent}}
          />

          <DButton
            @icon="trash-can"
            class="btn-danger"
            @action={{this.destroyPostEvent}}
          />
        {{else}}
          <DButton
            class="btn-primary"
            @label="discourse_post_event.builder_modal.create"
            @icon="calendar-day"
            @action={{this.createEvent}}
          />
        {{/if}}

        {{#if this.showScreenToggle}}
          <DButton
            class="btn-default advanced-settings
              {{if this.isAdvancedScreen 'is-active'}}"
            @icon="gear"
            @label="discourse_post_event.builder_modal.advanced_settings"
            @action={{this.toggleAdvanced}}
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
