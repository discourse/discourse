import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import PostEventBuilder from "discourse/plugins/discourse-calendar/discourse/components/modal/post-event-builder";
import {
  buildParams,
  camelCase,
  reconcileDefaultReminder,
  reminderToBBCode,
} from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import CompactEventEditor from "./compact-event-editor";

export default class EventNodeView extends Component {
  @service composer;
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked _previousRsvpStatus = "public";

  constructor() {
    super(...arguments);
    this.args.onSetup?.(this);
    const status = this.args.node?.attrs?.status;
    if (status && status !== "standalone") {
      this._previousRsvpStatus = status;
    }
  }

  updateNodeAttribute(attributeName, value) {
    if (!this.args.getPos || !this.args.view) {
      return;
    }

    next(() => {
      const { view } = this.args;
      const pos = this.args.getPos();
      const node = view.state.doc.nodeAt(pos);

      if (!node || node.attrs[attributeName] === value) {
        return;
      }

      const newAttrs = { ...node.attrs, [attributeName]: value };
      const tr = view.state.tr.setNodeMarkup(pos, null, newAttrs);
      view.dispatch(tr);
    });
  }

  updateNodeContent(content) {
    if (!this.args.getPos || !this.args.view) {
      return;
    }

    next(() => {
      const { view } = this.args;
      const pos = this.args.getPos();
      const node = view.state.doc.nodeAt(pos);

      if (!node) {
        return;
      }

      const tr = view.state.tr;
      const startPos = pos + 1;
      const endPos = pos + node.nodeSize - 1;

      if (content.trim()) {
        const textNode = view.state.schema.text(content);
        tr.replaceWith(startPos, endPos, textNode);
      } else {
        tr.delete(startPos, endPos);
      }

      view.dispatch(tr);
    });
  }

  get eventData() {
    return this.args.node.attrs;
  }

  get eventDescription() {
    return this.args.view.state.doc.textBetween(
      this.args.getPos() + 1,
      this.args.getPos() + this.args.node.nodeSize - 1,
      "\n",
      "\n"
    );
  }

  get resolvedTimezone() {
    return this.eventData.timezone || "UTC";
  }

  get userTimezone() {
    return this.currentUser?.user_option?.timezone || moment.tz.guess();
  }

  parseDateWithTimezone(dateString) {
    if (!dateString) {
      return null;
    }

    const date = moment.tz(dateString, this.resolvedTimezone);

    if (!date.isValid()) {
      return moment.tz(this.userTimezone);
    }

    return date;
  }

  get startsAt() {
    return this.parseDateWithTimezone(this.eventData.start);
  }

  get endsAt() {
    return this.parseDateWithTimezone(this.eventData.end);
  }

  get statusText() {
    const status =
      this.eventData.status === "standalone"
        ? "public"
        : this.eventData.status || "public";
    return i18n(`discourse_post_event.models.event.status.${status}.title`);
  }

  get allDay() {
    const v = this.eventData.allDay;
    return v === true || v === "true";
  }

  formatForAllDay(m, allDay) {
    return allDay ? m.format("YYYY-MM-DD") : m.format("YYYY-MM-DD HH:mm");
  }

  get eventNamePlaceholder() {
    return (
      this.composer?.get("model.title") ||
      i18n("discourse_post_event.composer.name_placeholder")
    );
  }

  @action
  testLocationUrl(value) {
    return this.args.pluginParams.utils.getLinkify().test(value);
  }

  @action
  updateName(value) {
    this.updateNodeAttribute("name", value);
  }

  @action
  updateLocation(value) {
    this.updateNodeAttribute("location", value);
  }

  @action
  updateDescription(value) {
    this.updateNodeContent(value);
  }

  @action
  updateStart(newMoment) {
    const eventTz = this.resolvedTimezone;
    const m = newMoment ? newMoment.clone().tz(eventTz) : moment().tz(eventTz);
    this.#updateAttrsWithReconcile({
      start: this.formatForAllDay(m, this.allDay),
    });
  }

  @action
  updateEnd(newMoment) {
    const eventTz = this.resolvedTimezone;
    const value = newMoment
      ? this.formatForAllDay(newMoment.clone().tz(eventTz), this.allDay)
      : null;
    this.#updateAttrsWithReconcile({ end: value });
  }

  @action
  updateAllDay(allDay) {
    this.#updateAttrsWithReconcile((attrs) => {
      const eventTz = attrs.timezone || "UTC";
      const updates = { allDay: allDay ? "true" : null };
      const startM = attrs.start ? moment.tz(attrs.start, eventTz) : null;

      if (allDay) {
        const startDate = (startM ?? moment.tz(eventTz)).format("YYYY-MM-DD");
        updates.start = startDate;
        updates.end = startDate;
      } else if (startM) {
        const nowTime = moment.tz(eventTz);
        const newStart = startM
          .clone()
          .hour(nowTime.hour())
          .minute(nowTime.minute())
          .second(0)
          .millisecond(0);
        updates.start = newStart.format("YYYY-MM-DD HH:mm");
        updates.end = newStart
          .clone()
          .add(1, "hour")
          .format("YYYY-MM-DD HH:mm");
      }

      return updates;
    });
  }

  #configFromAttrs(attrs) {
    const eventTz = attrs.timezone || "UTC";
    return {
      startsAt: attrs.start ? moment.tz(attrs.start, eventTz) : null,
      endsAt: attrs.end ? moment.tz(attrs.end, eventTz) : null,
      allDay: attrs.allDay === "true" || attrs.allDay === true,
    };
  }

  #updateAttrsWithReconcile(updatesOrFn) {
    if (!this.args.getPos || !this.args.view) {
      return;
    }

    next(() => {
      const { view } = this.args;
      const pos = this.args.getPos();
      const node = view.state.doc.nodeAt(pos);
      if (!node) {
        return;
      }

      const updates =
        typeof updatesOrFn === "function"
          ? updatesOrFn(node.attrs)
          : updatesOrFn;
      const newAttrs = { ...node.attrs, ...updates };

      if (!("reminders" in updates)) {
        const reconciled = reconcileDefaultReminder(
          this.parseReminders(node.attrs.reminders),
          this.#configFromAttrs(node.attrs),
          this.#configFromAttrs(newAttrs)
        );
        newAttrs.reminders =
          reconciled && reconciled.length
            ? reconciled.map(reminderToBBCode).join(",")
            : null;
      }

      const allKeys = new Set([
        ...Object.keys(node.attrs),
        ...Object.keys(newAttrs),
      ]);
      const noChange = [...allKeys].every(
        (key) => newAttrs[key] === node.attrs[key]
      );
      if (noChange) {
        return;
      }

      const tr = view.state.tr.setNodeMarkup(pos, null, newAttrs);
      view.dispatch(tr);
    });
  }

  @action
  updateMaxAttendees(value) {
    this.#updateAttrsWithReconcile((attrs) => {
      if (value === 0) {
        if (attrs.status && attrs.status !== "standalone") {
          this._previousRsvpStatus = attrs.status;
        }
        const flipped = this.parseReminders(attrs.reminders).map((r) =>
          r.type === "notification" ? { ...r, type: "bumpTopic" } : r
        );
        return {
          maxAttendees: null,
          status: "standalone",
          reminders: flipped.length
            ? flipped.map(reminderToBBCode).join(",")
            : null,
        };
      }

      if (attrs.status === "standalone" && value > 0) {
        const flipped = this.parseReminders(attrs.reminders).map((r) =>
          r.type === "bumpTopic" ? { ...r, type: "notification" } : r
        );
        return {
          maxAttendees: value,
          status: this._previousRsvpStatus || "public",
          reminders: flipped.length
            ? flipped.map(reminderToBBCode).join(",")
            : null,
        };
      }

      return { maxAttendees: value };
    });
  }

  get parsedReminders() {
    return this.parseReminders(this.eventData.reminders);
  }

  @action
  updateReminders(reminders) {
    const value =
      reminders && reminders.length
        ? reminders.map(reminderToBBCode).join(",")
        : null;
    this.updateNodeAttribute("reminders", value);
  }

  parseReminders(reminders) {
    if (!reminders) {
      return [];
    }

    if (Array.isArray(reminders)) {
      return reminders;
    }

    return reminders.split(",").map((reminderStr) => {
      const [type, value, unit] = reminderStr.split(".");
      const numericValue = Math.abs(parseInt(value, 10));

      return {
        type: type || "notification",
        value: numericValue,
        unit: unit || "hours",
        period: parseInt(value, 10) < 0 ? "after" : "before",
      };
    });
  }

  parseCustomFields() {
    const customFields = {};
    const allowedCustomFields =
      this.siteSettings.discourse_post_event_allowed_custom_fields
        .split("|")
        .filter(Boolean);

    allowedCustomFields.forEach((fieldName) => {
      const camelCaseName = camelCase(fieldName);
      if (typeof this.eventData[camelCaseName] !== "undefined") {
        customFields[fieldName] = this.eventData[camelCaseName];
      }
    });

    return customFields;
  }

  convertNodeToEvent() {
    const timezone = this.eventData.timezone || "UTC";

    return {
      name: this.eventData.name,
      location: this.eventData.location,
      description: this.eventDescription,
      timezone,
      status: this.eventData.status || "public",
      max_attendees: this.eventData.maxAttendees,
      show_local_time: this.eventData.showLocalTime,
      chat_enabled: this.eventData.chatEnabled,
      minimal: this.eventData.minimal,
      all_day: this.allDay,
      reminders: this.parseReminders(this.eventData.reminders) || [],
      raw_invitees: this.eventData.allowedGroups?.split(",") || [],
      custom_fields: this.parseCustomFields(),
      starts_at: this.eventData.start
        ? moment(this.eventData.start).tz(timezone)
        : moment.tz(timezone),
      ends_at: this.eventData.end
        ? moment(this.eventData.end).tz(timezone)
        : null,
      image_upload: this.eventData.image ? { url: this.eventData.image } : null,
    };
  }

  @action
  openEventBuilder() {
    const eventData = this.convertNodeToEvent();

    this.modal.show(PostEventBuilder, {
      model: {
        event: DiscoursePostEventEvent.create(eventData),
        initialScreen: "advanced",
        onDelete: () => {
          if (!this.args.getPos || !this.args.view) {
            return;
          }

          const { view } = this.args;
          const pos = this.args.getPos();
          const node = view.state.doc.nodeAt(pos);

          if (!node) {
            return;
          }

          const tr = view.state.tr.delete(pos, pos + node.nodeSize);
          view.dispatch(tr);

          return true;
        },
        onUpdate: (startsAt, endsAt, event) => {
          const params = buildParams(
            startsAt,
            endsAt,
            event,
            this.siteSettings
          );
          const description = params.description ?? "";
          delete params.description;

          const customFieldAttrs =
            this.siteSettings.discourse_post_event_allowed_custom_fields
              .split("|")
              .filter(Boolean)
              .map((f) => camelCase(f));
          const clearableAttrs = [
            "end",
            "maxAttendees",
            "name",
            "location",
            "url",
            "timezone",
            "recurrence",
            "recurrenceUntil",
            "showLocalTime",
            "minimal",
            "chatEnabled",
            "allDay",
            "allowedGroups",
            "reminders",
            "image",
            "closed",
            ...customFieldAttrs,
          ];
          for (const attr of clearableAttrs) {
            if (!(attr in params)) {
              this.updateNodeAttribute(attr, null);
            }
          }

          for (const [field, value] of Object.entries(params)) {
            this.updateNodeAttribute(field, value);
          }

          this.updateNodeContent(description);
        },
      },
    });
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  stopEvent(event) {
    return event.target.matches("input, textarea, button");
  }

  <template>
    <CompactEventEditor
      @name={{this.eventData.name}}
      @location={{this.eventData.location}}
      @description={{this.eventDescription}}
      @maxAttendees={{this.eventData.maxAttendees}}
      @reminders={{this.parsedReminders}}
      @startsAt={{this.startsAt}}
      @endsAt={{this.endsAt}}
      @allDay={{this.allDay}}
      @timezone={{this.resolvedTimezone}}
      @userTimezone={{this.userTimezone}}
      @status={{this.eventData.status}}
      @statusText={{this.statusText}}
      @namePlaceholder={{this.eventNamePlaceholder}}
      @urlTester={{this.testLocationUrl}}
      @onUpdateName={{this.updateName}}
      @onUpdateLocation={{this.updateLocation}}
      @onUpdateDescription={{this.updateDescription}}
      @onUpdateStart={{this.updateStart}}
      @onUpdateEnd={{this.updateEnd}}
      @onUpdateAllDay={{this.updateAllDay}}
      @onUpdateMaxAttendees={{this.updateMaxAttendees}}
      @onUpdateReminders={{this.updateReminders}}
      @onOpenAdvanced={{this.openEventBuilder}}
    />
  </template>
}
