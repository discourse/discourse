import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import AdvancedModeToggle from "discourse/components/advanced-mode-toggle";
import Form from "discourse/components/form";
import GroupSelector from "discourse/components/group-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { extractError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import { eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import DDateInput from "discourse/ui-kit/d-date-input";
import DDateTimeInput from "discourse/ui-kit/d-date-time-input";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { recurrenceContext } from "../../lib/event-recurrence";
import {
  attendanceTransition,
  buildEventBlock,
  buildParams,
  customFieldFormName,
  defaultEventState,
  defaultReminderFor,
  getCustomFieldNames,
  isLivestreamUrl,
  livestreamSource,
  reconcileDefaultReminder,
} from "../../lib/raw-event-helper";
import CompactEventEditor from "../compact-event-editor";

export default class PostEventBuilder extends Component {
  @service dialog;
  @service siteSettings;
  @service currentUser;

  @tracked flash = null;
  @tracked isSaving = false;
  @tracked screen = this.args.model.initialScreen || "compact";

  @tracked allDay = this.event.allDay || false;
  @tracked startsAt = this.#initStartsAt();
  @tracked endsAt = this.#initEndsAt();
  @tracked
  previousRsvpStatus =
    this.event.status === "standalone" ? "public" : this.event.status;
  @tracked previousMaxAttendees = this.event.maxAttendees || null;
  @tracked attendanceMode = this.#initAttendanceMode();
  @tracked urlRevealed = !!this.event.url;

  // FormKit clones @data once on mount and treats it as immutable. Reading
  // tracked event properties from a getter would invalidate this on every
  // mirror-write and reinitialize the form (losing focus mid-keystroke).
  // Snapshot once at construction; refresh only when toggleAdvanced enters
  // the advanced screen.
  @tracked formData = this.#snapshotFormData();

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

  get locationLabel() {
    return this.urlRevealed
      ? "discourse_post_event.builder_modal.location.label"
      : "discourse_post_event.builder_modal.location.label_or_url";
  }

  get showLivestream() {
    return (
      isLivestreamUrl(this.#livestreamSource(), this.siteSettings) &&
      this.siteSettings.chat_enabled
    );
  }

  get availableRecurrences() {
    const { weekday, ordinal } = recurrenceContext(this.startsAt || moment());

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

  @cached
  get allowedCustomFields() {
    return getCustomFieldNames(this.siteSettings).map((field) => ({
      field,
      name: customFieldFormName(field),
    }));
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

  get namePlaceholder() {
    return this.args.model.event?.post?.topic?.title;
  }

  get compactInitialState() {
    return {
      ...defaultEventState(),
      name: this.event.name ?? null,
      location: this.event.location ?? null,
      description: this.event.description ?? "",
      timezone: this.event.timezone ?? "UTC",
      status: this.event.status ?? "public",
      maxAttendees: this.event.maxAttendees ?? null,
      allDay: !!this.allDay,
      startsAt: this.startsAt,
      endsAt: this.endsAt,
      reminders: this.event.reminders ?? [],
      recurrence: this.event.recurrence ?? null,
      recurrenceUntil: this.event.recurrenceUntil ?? null,
      showLocalTime: !!this.event.showLocalTime,
      chatEnabled: !!this.event.chatEnabled,
      livestream: !!this.event.livestream,
      minimal: !!this.event.minimal,
      url: this.event.url ?? null,
      image:
        this.event.imageUpload?.short_url ??
        this.event.imageUpload?.url ??
        null,
      allowedGroups: (this.event.rawInvitees || []).join(",") || null,
      closed: !!this.event.isClosed,
      customFields: { ...(this.event.customFields || {}) },
    };
  }

  get allowsRsvps() {
    return this.event.status !== "standalone";
  }

  @action
  registerForm(api) {
    this.formApi = api;
  }

  // mirror and change back to event model to keep compact view synced
  @action
  syncFieldToEvent(field, value, { set }) {
    set(field, value);
    this.event[field] = value;
  }

  @action
  syncLinkToEvent(field, value, { set }) {
    set(field, value);
    this.event[field] = value;
    this.#resetInvalidLivestream(set);
  }

  @action
  handleAllDayChange(value, { set }) {
    set("allDay", value);
    this.updateAllDay(value);
  }

  @action
  handleAttendanceModeChange(value, { set }) {
    set("attendanceMode", value);
    // setAttendanceMode mirrors the resulting state back to the form
    this.setAttendanceMode(value);
  }

  @action
  handleMaxAttendeesChange(value, { set }) {
    set("maxAttendees", value);
    if (value === 0) {
      this.setAttendanceMode("none");
      return;
    }
    if (value > 0) {
      this.#applyUpToValue(value);
      return;
    }
    // just clear the data
    this.event.maxAttendees = null;
  }

  @action
  handleEventTypeChange(value, { set }) {
    set("eventType", value);
    this.onChangeStatus(value);
  }

  // GroupSelector uses (_, newGroups). Adapt to the form's field setter and
  // mirror onto event so the BBCode build picks it up.
  @action
  handleInviteesChange(_, newInvitees) {
    this.formApi?.set("rawInvitees", newInvitees);
    this.event.rawInvitees = newInvitees;
  }

  @action
  handleRecurrenceChange(value, { set }) {
    set("recurrence", value);
    this.setRecurrence(value);
  }

  @action
  handleImageChange(value, { set }) {
    set("imageUpload", value?.url ?? null);
    this.event.imageUpload = value ?? null;
  }

  @action
  handleTimezoneChange(value, { set }) {
    set("timezone", value);
    // setNewTimezone re-anchors startsAt/endsAt in the new zone.
    this.setNewTimezone(value);
  }

  @action
  handleReminderFieldChange(field, index, value, { set }) {
    set(field, value);
    if (!this.event.reminders?.[index]) {
      return;
    }
    this.event.reminders = this.event.reminders.map((r, i) =>
      i === index ? { ...r, [field]: value } : r
    );
  }

  @action
  handleAddReminder(addItemToCollection) {
    const def = defaultReminderFor({
      startsAt: this.startsAt,
      endsAt: this.endsAt,
      allDay: this.allDay,
    });
    const reminder = {
      type: this.allowsRsvps ? def.type : "bumpTopic",
      value: def.value,
      unit: def.unit,
      period: def.period,
    };
    this.event.addReminder(reminder);
    addItemToCollection("reminders", { ...reminder });
  }

  @action
  handleRemoveReminder(index, collectionRemove) {
    this.event.reminders.splice(index, 1);
    collectionRemove(index);
  }

  @action
  revealUrl() {
    this.urlRevealed = true;
  }

  @action
  onCompactChange(state) {
    this.event.name = state.name;
    this.event.location = state.location || "";
    this.event.description = state.description;
    this.event.timezone = state.timezone;
    this.event.status = state.status;
    this.event.maxAttendees = state.maxAttendees;
    this.event.showLocalTime = state.showLocalTime;
    this.event.chatEnabled = state.chatEnabled;
    this.event.livestream = state.livestream;
    this.event.minimal = state.minimal;
    this.event.url = state.url;
    this.event.recurrence = state.recurrence;
    this.event.recurrenceUntil = state.recurrenceUntil;
    this.event.reminders = state.reminders;
    this.event.rawInvitees = state.allowedGroups
      ? state.allowedGroups.split(",")
      : [];
    this.event.allDay = state.allDay;
    this.event.startsAt = state.startsAt;
    this.event.endsAt = state.endsAt;
    this.event.isClosed = state.closed;
    this.event.imageUpload = state.image ? { url: state.image } : null;
    this.event.customFields = EmberObject.create({
      ...(state.customFields || {}),
    });
    this.allDay = state.allDay;
    this.startsAt = state.startsAt;
    this.endsAt = state.endsAt;

    if (state.status === "standalone") {
      this.attendanceMode = "none";
    } else if (state.maxAttendees) {
      this.attendanceMode = "upTo";
      this.previousMaxAttendees = state.maxAttendees;
    } else {
      this.attendanceMode = "unlimited";
    }
    if (state.status && state.status !== "standalone") {
      this.previousRsvpStatus = state.status;
    }
  }

  @action
  toggleAdvanced() {
    if (this.isAdvancedScreen) {
      // Leaving advanced — drop the stale form API reference.
      this.formApi = null;
      this.screen = "compact";
    } else {
      // Entering advanced — re-snapshot from the (possibly compact-edited)
      // event before the form mounts.
      this.formData = this.#snapshotFormData();
      this.urlRevealed ||= !!this.event.url;
      this.screen = "advanced";
    }
  }

  @action
  updateAllDay(allDay) {
    const prev = this.#captureConfig();
    this.allDay = allDay;
    this.event.allDay = allDay;
    if (allDay) {
      const tz = this.event.timezone || "UTC";
      const snapped = (this.startsAt ?? moment.tz(tz)).clone().startOf("day");
      this.startsAt = snapped;
      this.event.startsAt = snapped;

      const existingEnd = this.endsAt;
      let newEnd = null;
      if (existingEnd) {
        const startDate = snapped.format("YYYY-MM-DD");
        const endDate = existingEnd.format("YYYY-MM-DD");
        if (endDate !== startDate) {
          newEnd = existingEnd.clone().startOf("day");
        }
      }
      this.endsAt = newEnd;
      this.event.endsAt = newEnd;
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
    this.#reconcileReminder(prev);
  }

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  }

  @action
  setCustomField(field, value, { set, name }) {
    set(name, value);
    this.event.customFields = EmberObject.create({
      ...this.event.customFields,
      [field]: value,
    });
  }

  @action
  onChangeDates(dates) {
    const prev = this.#captureConfig();
    this.event.startsAt = dates.from;
    this.event.endsAt = dates.to;
    this.startsAt = dates.from;
    this.endsAt = dates.to;
    this.#reconcileReminder(prev);
  }

  @action
  onChangeStartsAt(set, value) {
    const to =
      value && this.endsAt && value.isAfter(this.endsAt)
        ? value.clone().add(1, "hour")
        : this.endsAt;
    this.onChangeDates({ from: value, to });
    set(value);
  }

  @action
  onChangeEndsAt(set, value) {
    const to =
      value && this.startsAt && value.isBefore(this.startsAt)
        ? this.startsAt.clone().add(1, "hour")
        : value;
    this.onChangeDates({ from: this.startsAt, to });
    set(to);
  }

  @action
  setAttendanceMode(mode) {
    this.attendanceMode = mode;
    const next = attendanceTransition({
      mode,
      status: this.event.status,
      maxAttendees: this.event.maxAttendees,
      reminders: this.event.reminders,
      previousRsvpStatus: this.previousRsvpStatus,
      previousMaxAttendees: this.previousMaxAttendees,
    });
    this.event.status = next.status;
    this.event.maxAttendees = next.maxAttendees;
    this.event.reminders = next.reminders;
    this.previousRsvpStatus = next.previousRsvpStatus;
    this.previousMaxAttendees = next.previousMaxAttendees;
    this.formApi?.setProperties({
      attendanceMode: mode,
      maxAttendees: next.maxAttendees,
      eventType:
        next.status === "standalone"
          ? this.previousRsvpStatus || "public"
          : next.status,
    });
    this.#syncRemindersToForm();
  }

  @action
  onChangeStatus(newStatus) {
    this.event.rawInvitees = [];
    this.event.status = newStatus;
    this.formApi?.set("rawInvitees", []);
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

    this.args.model.toolbarEvent.addText(
      buildEventBlock(eventParams, eventParams.description)
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

  #initAttendanceMode() {
    if (this.event.status === "standalone") {
      return "none";
    }
    return this.event.maxAttendees ? "upTo" : "unlimited";
  }

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

  #snapshotFormData() {
    return {
      name: this.event.name ?? "",
      location: this.event.location ?? "",
      url: this.event.url ?? "",
      description: this.event.description ?? "",
      startsAt: this.startsAt ?? null,
      endsAt: this.endsAt ?? null,
      allDay: !!this.event.allDay,
      showLocalTime: !!this.event.showLocalTime,
      chatEnabled: !!this.event.chatEnabled,
      livestream: !!this.event.livestream,
      attendanceMode: this.attendanceMode,
      maxAttendees: this.event.maxAttendees ?? null,
      eventType:
        this.event.status === "standalone"
          ? this.previousRsvpStatus || "public"
          : this.event.status || "public",
      rawInvitees: this.event.rawInvitees ?? [],
      recurrence: this.event.recurrence ?? null,
      imageUpload: this.event.imageUpload?.url ?? null,
      timezone: this.event.timezone ?? null,
      reminders: (this.event.reminders ?? []).map((r) => ({ ...r })),
      customFields: this.#formCustomFields(),
    };
  }

  #formCustomFields() {
    const fields = {};
    for (const [key, value] of Object.entries(this.event.customFields ?? {})) {
      fields[customFieldFormName(key)] = value;
    }
    return fields;
  }

  #livestreamSource() {
    return livestreamSource(this.event.location, this.event.url);
  }

  #resetInvalidLivestream(set) {
    if (!isLivestreamUrl(this.#livestreamSource(), this.siteSettings)) {
      set("livestream", false);
      this.event.livestream = false;
    }
  }

  #applyUpToValue(value) {
    if (this.event.status === "standalone") {
      this.event.status = this.previousRsvpStatus || "public";
      this.event.reminders = (this.event.reminders || []).map((r) =>
        r.type === "bumpTopic" ? { ...r, type: "notification" } : r
      );
      this.#syncRemindersToForm();
    }
    this.attendanceMode = "upTo";
    this.event.maxAttendees = value;
    this.previousMaxAttendees = value;
    this.formApi?.setProperties({
      attendanceMode: "upTo",
      maxAttendees: value,
      eventType: this.event.status,
    });
  }

  #syncRemindersToForm() {
    if (!this.formApi) {
      return;
    }
    this.formApi.set(
      "reminders",
      (this.event.reminders ?? []).map((r) => ({ ...r }))
    );
  }

  #captureConfig() {
    return {
      startsAt: this.startsAt,
      endsAt: this.endsAt,
      allDay: this.allDay,
    };
  }

  #reconcileReminder(prevConfig) {
    const next = reconcileDefaultReminder(
      this.event.reminders,
      prevConfig,
      this.#captureConfig()
    );
    if (next !== this.event.reminders) {
      this.event.reminders = next;
    }
  }

  <template>
    <DModal
      class="post-event-builder-modal
        {{if this.isAdvancedScreen 'is-advanced' 'is-compact'}}"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @inline={{@inline}}
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
    >
      <:body>
        <DConditionalLoadingSection @isLoading={{this.isSaving}}>
          {{#if this.isAdvancedScreen}}
            <Form
              @data={{this.formData}}
              @onRegisterApi={{this.registerForm}}
              as |form|
            >
              <PluginOutlet
                @connectorTagName="div"
                @name="post-event-builder-form"
                @outletArgs={{lazyHash event=@model.event form=form}}
              >
                <form.Field
                  @format="full"
                  @name="startsAt"
                  @title={{i18n
                    "discourse_post_event.builder_modal.starts_at.label"
                  }}
                  @type="custom"
                  @validation="required"
                  as |field|
                >
                  <field.Control>
                    <DDateTimeInput
                      class="from"
                      @date={{this.startsAt}}
                      @onChange={{fn this.onChangeStartsAt field.set}}
                      @placeholder={{i18n "dates.from_placeholder"}}
                      @showTime={{this.showTime}}
                      @timezone={{@model.event.timezone}}
                    />
                  </field.Control>
                </form.Field>

                <form.Field
                  @format="full"
                  @name="endsAt"
                  @title={{i18n
                    "discourse_post_event.builder_modal.ends_at.label"
                  }}
                  @type="custom"
                  @validation="required"
                  as |field|
                >
                  <field.Control>
                    <DDateTimeInput
                      class="to"
                      @date={{this.endsAt}}
                      @onChange={{fn this.onChangeEndsAt field.set}}
                      @placeholder={{i18n "dates.to_placeholder"}}
                      @relativeDate={{this.startsAt}}
                      @showTime={{this.showTime}}
                      @timezone={{@model.event.timezone}}
                    />
                  </field.Control>
                </form.Field>

                <form.Field
                  @format="full"
                  @name="allDay"
                  @onSet={{this.handleAllDayChange}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.all_day.label"
                  }}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control>
                    {{i18n
                      "discourse_post_event.builder_modal.all_day.description"
                    }}
                  </field.Control>
                </form.Field>

                <form.Field
                  @format="full"
                  @name="name"
                  @onSet={{fn this.syncFieldToEvent "name"}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.name.label"
                  }}
                  @type="input"
                  as |field|
                >
                  <field.Control
                    placeholder={{i18n
                      "discourse_post_event.builder_modal.name.placeholder"
                    }}
                  />
                </form.Field>

                <form.Field
                  @format="full"
                  @name="location"
                  @onSet={{fn this.syncLinkToEvent "location"}}
                  @title={{i18n this.locationLabel}}
                  @type="input"
                  as |field|
                >
                  <field.Control
                    placeholder={{i18n
                      "discourse_post_event.builder_modal.location.placeholder"
                    }}
                  />
                </form.Field>

                {{#if this.urlRevealed}}
                  <form.Field
                    @format="full"
                    @name="url"
                    @onSet={{fn this.syncLinkToEvent "url"}}
                    @title={{i18n
                      "discourse_post_event.builder_modal.url.label"
                    }}
                    @type="input"
                    as |field|
                  >
                    <field.Control
                      placeholder={{i18n
                        "discourse_post_event.builder_modal.url.placeholder"
                      }}
                    />
                  </form.Field>
                {{else}}
                  <form.Container @format="full">
                    <DButton
                      class="btn-default add-event-url"
                      @action={{this.revealUrl}}
                      @icon="plus"
                      @label="discourse_post_event.builder_modal.url.add"
                    />
                  </form.Container>
                {{/if}}

                {{#if this.showLivestream}}
                  <form.Field
                    @format="full"
                    @name="livestream"
                    @onSet={{fn this.syncFieldToEvent "livestream"}}
                    @title={{i18n
                      "discourse_post_event.builder_modal.livestream.label"
                    }}
                    @type="checkbox"
                    as |field|
                  >
                    <field.Control>
                      {{i18n
                        "discourse_post_event.builder_modal.livestream.checkbox_label"
                      }}
                    </field.Control>
                  </form.Field>
                {{/if}}

                <form.Field
                  @format="full"
                  @name="description"
                  @onSet={{fn this.syncFieldToEvent "description"}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.description.label"
                  }}
                  @type="textarea"
                  as |field|
                >
                  <field.Control
                    placeholder={{i18n
                      "discourse_post_event.builder_modal.description.placeholder"
                    }}
                    @autoResize={{true}}
                  />
                </form.Field>

                <form.Field
                  @format="full"
                  @name="attendanceMode"
                  @onSet={{this.handleAttendanceModeChange}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.attendance.label"
                  }}
                  @type="radio-group"
                  @validation="required"
                  as |field|
                >
                  <field.Control as |radioGroup|>
                    <radioGroup.Radio @value="unlimited" as |radio|>
                      <radio.Title>
                        {{i18n
                          "discourse_post_event.builder_modal.attendance.unlimited"
                        }}
                      </radio.Title>
                    </radioGroup.Radio>
                    <radioGroup.Radio @value="upTo" as |radio|>
                      <radio.Title>
                        {{i18n
                          "discourse_post_event.builder_modal.attendance.up_to"
                        }}
                      </radio.Title>
                      <radio.Description>
                        <form.Field
                          @disabled={{not (eq field.value "upTo")}}
                          @name="maxAttendees"
                          @onSet={{this.handleMaxAttendeesChange}}
                          @showTitle={{false}}
                          @title={{i18n
                            "discourse_post_event.builder_modal.max_attendees.label"
                          }}
                          @type="input-number"
                          as |maxField|
                        >
                          <maxField.Control min="0" />
                        </form.Field>
                      </radio.Description>
                    </radioGroup.Radio>
                    <radioGroup.Radio @value="none" as |radio|>
                      <radio.Title>
                        {{i18n
                          "discourse_post_event.builder_modal.attendance.none"
                        }}
                      </radio.Title>
                    </radioGroup.Radio>
                  </field.Control>
                </form.Field>

                {{#if this.allowsRsvps}}
                  <form.Field
                    @format="full"
                    @name="eventType"
                    @onSet={{this.handleEventTypeChange}}
                    @title={{i18n
                      "discourse_post_event.builder_modal.event_type.label"
                    }}
                    @type="radio-group"
                    @validation="required"
                    as |field|
                  >
                    <field.Control as |radioGroup|>
                      <radioGroup.Radio @value="public" as |radio|>
                        <radio.Title>
                          {{i18n
                            "discourse_post_event.builder_modal.event_type.public.title"
                          }}
                        </radio.Title>
                        <radio.Description>
                          {{i18n
                            "discourse_post_event.builder_modal.event_type.public.description"
                          }}
                        </radio.Description>
                      </radioGroup.Radio>
                      <radioGroup.Radio @value="private" as |radio|>
                        <radio.Title>
                          {{i18n
                            "discourse_post_event.builder_modal.event_type.private.title"
                          }}
                        </radio.Title>
                        <radio.Description>
                          {{i18n
                            "discourse_post_event.builder_modal.event_type.private.description"
                          }}
                        </radio.Description>
                      </radioGroup.Radio>
                    </field.Control>
                  </form.Field>

                  {{#if (eq @model.event.status "private")}}
                    <form.Field
                      @format="full"
                      @name="rawInvitees"
                      @title={{i18n
                        "discourse_post_event.builder_modal.invitees.label"
                      }}
                      @type="custom"
                      as |field|
                    >
                      <field.Control>
                        <GroupSelector
                          @groupFinder={{this.groupFinder}}
                          @groupNames={{field.value}}
                          @onChangeCallback={{this.handleInviteesChange}}
                          @placeholderKey="topic.invite_private.group_name"
                        />
                      </field.Control>
                    </form.Field>
                  {{/if}}
                {{/if}}

                <form.Field
                  @format="full"
                  @name="timezone"
                  @onSet={{this.handleTimezoneChange}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.timezone.label"
                  }}
                  @type="custom"
                  @validation="required"
                  as |field|
                >
                  <field.Control>
                    <TimezoneInput
                      @none="discourse_post_event.builder_modal.timezone.remove_timezone"
                      @onChange={{field.set}}
                      @value={{field.value}}
                    />
                  </field.Control>
                </form.Field>

                <form.Field
                  @format="full"
                  @name="showLocalTime"
                  @onSet={{fn this.syncFieldToEvent "showLocalTime"}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.show_local_time.label"
                  }}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control>
                    {{i18n
                      "discourse_post_event.builder_modal.show_local_time.description"
                      timezone=@model.event.timezone
                    }}
                  </field.Control>
                </form.Field>

                <form.Container
                  class="reminders"
                  @format="full"
                  @optional={{true}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.reminders.label"
                  }}
                >
                  <form.Collection
                    class="reminders-list"
                    @name="reminders"
                    as |collection index|
                  >
                    <div class="reminder-item">
                      <collection.Field
                        class="reminder-type"
                        @name="type"
                        @onSet={{fn
                          this.handleReminderFieldChange
                          "type"
                          index
                        }}
                        @showTitle={{false}}
                        @title={{i18n
                          "discourse_post_event.builder_modal.reminders.types.notification"
                        }}
                        @type="select"
                        @validation="required"
                        as |field|
                      >
                        <field.Control as |select|>
                          {{#each this.reminderTypes as |opt|}}
                            <select.Option
                              @value={{opt.value}}
                            >{{opt.name}}</select.Option>
                          {{/each}}
                        </field.Control>
                      </collection.Field>

                      <collection.Field
                        class="reminder-value"
                        @name="value"
                        @onSet={{fn
                          this.handleReminderFieldChange
                          "value"
                          index
                        }}
                        @showTitle={{false}}
                        @title={{i18n
                          "discourse_post_event.builder_modal.reminders.label"
                        }}
                        @type="input-number"
                        as |field|
                      >
                        <field.Control min="0" />
                      </collection.Field>

                      <collection.Field
                        class="reminder-unit"
                        @name="unit"
                        @onSet={{fn
                          this.handleReminderFieldChange
                          "unit"
                          index
                        }}
                        @showTitle={{false}}
                        @title={{i18n
                          "discourse_post_event.builder_modal.reminders.units.minutes"
                        }}
                        @type="select"
                        @validation="required"
                        as |field|
                      >
                        <field.Control as |select|>
                          {{#each this.reminderUnits as |opt|}}
                            <select.Option
                              @value={{opt.value}}
                            >{{opt.name}}</select.Option>
                          {{/each}}
                        </field.Control>
                      </collection.Field>

                      <div class="reminder-period">
                        {{i18n
                          "discourse_post_event.builder_modal.reminders.periods.before"
                        }}

                        <DButton
                          class="btn-default remove-reminder"
                          @action={{fn
                            this.handleRemoveReminder
                            index
                            collection.remove
                          }}
                          @icon="xmark"
                        />
                      </div>
                    </div>
                  </form.Collection>

                  <DButton
                    class="btn-default add-reminder"
                    @action={{fn
                      this.handleAddReminder
                      form.addItemToCollection
                    }}
                    @disabled={{this.addReminderDisabled}}
                    @icon="plus"
                    @label="discourse_post_event.builder_modal.add_reminder"
                  />
                </form.Container>

                <form.Field
                  @format="full"
                  @name="recurrence"
                  @onSet={{this.handleRecurrenceChange}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.recurrence.label"
                  }}
                  @type="select"
                  as |field|
                >
                  <field.Control as |select|>
                    {{#each this.availableRecurrences as |rec|}}
                      <select.Option
                        @value={{rec.id}}
                      >{{rec.name}}</select.Option>
                    {{/each}}
                  </field.Control>
                </form.Field>

                {{#if @model.event.recurrence}}
                  <form.Container
                    class="recurrence-until"
                    @format="full"
                    @title={{i18n
                      "discourse_post_event.builder_modal.recurrence_until.label"
                    }}
                  >
                    <DDateInput
                      @date={{this.recurrenceUntil}}
                      @onChange={{this.setRecurrenceUntil}}
                      @timezone={{@model.event.timezone}}
                    />
                  </form.Container>
                {{/if}}

                {{#if this.showChat}}
                  <form.Field
                    @format="full"
                    @name="chatEnabled"
                    @onSet={{fn this.syncFieldToEvent "chatEnabled"}}
                    @title={{i18n
                      "discourse_post_event.builder_modal.allow_chat.label"
                    }}
                    @type="checkbox"
                    as |field|
                  >
                    <field.Control>
                      {{i18n
                        "discourse_post_event.builder_modal.allow_chat.checkbox_label"
                      }}
                    </field.Control>
                  </form.Field>
                {{/if}}

                {{#if this.allowedCustomFields.length}}
                  <PluginOutlet
                    @connectorTagName="div"
                    @name="discourse-post-event-builder-custom-fields"
                    @outletArgs={{lazyHash event=@model.event form=form}}
                  >
                    <form.Container
                      class="form-kit__container-custom-fields"
                      @format="full"
                      @subtitle={{i18n
                        "discourse_post_event.builder_modal.custom_fields.description"
                      }}
                      @title={{i18n
                        "discourse_post_event.builder_modal.custom_fields.label"
                      }}
                    >
                      <form.Object @name="customFields" as |customFields|>
                        {{#each this.allowedCustomFields as |customField|}}
                          <customFields.Field
                            @format="full"
                            @name={{customField.name}}
                            @onSet={{fn this.setCustomField customField.field}}
                            @title={{customField.field}}
                            @type="input"
                            as |field|
                          >
                            <field.Control
                              placeholder={{i18n
                                "discourse_post_event.builder_modal.custom_fields.placeholder"
                              }}
                            />
                          </customFields.Field>
                        {{/each}}
                      </form.Object>
                    </form.Container>
                  </PluginOutlet>
                {{/if}}

                <form.Field
                  @format="full"
                  @name="imageUpload"
                  @onSet={{this.handleImageChange}}
                  @title={{i18n
                    "discourse_post_event.builder_modal.image.label"
                  }}
                  @type="image"
                  as |field|
                >
                  <field.Control @type="event_image" />
                </form.Field>
              </PluginOutlet>
            </Form>
          {{else}}
            <div class="composer-event-node">
              <CompactEventEditor
                @hideAdvanced={{true}}
                @initialState={{this.compactInitialState}}
                @namePlaceholder={{this.namePlaceholder}}
                @onChange={{this.onCompactChange}}
              />
            </div>
          {{/if}}
        </DConditionalLoadingSection>
      </:body>
      <:footer>
        {{#if @model.onUpdate}}
          <DButton
            class="btn-primary"
            @action={{this.updateEvent}}
            @icon="calendar-day"
            @label="discourse_post_event.builder_modal.update"
          />

          <DButton
            class="btn-danger"
            @action={{this.destroyPostEvent}}
            @icon="trash-can"
          />
        {{else}}
          <DButton
            class="btn-primary"
            @action={{this.createEvent}}
            @icon="calendar-day"
            @label="discourse_post_event.builder_modal.create"
          />
        {{/if}}

        {{#if this.showScreenToggle}}
          <AdvancedModeToggle
            @active={{this.isAdvancedScreen}}
            @onToggle={{this.toggleAdvanced}}
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
