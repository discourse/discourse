import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ExpandingTextArea from "discourse/components/expanding-text-area";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PostEventBuilder from "discourse/plugins/discourse-calendar/discourse/components/modal/post-event-builder";
import guessDateFormat from "discourse/plugins/discourse-calendar/discourse/lib/guess-best-date-format";
import {
  buildParams,
  camelCase,
} from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";

export default class EventNodeView extends Component {
  @service composer;
  @service currentUser;
  @service modal;
  @service siteSettings;
  @service capabilities;

  constructor() {
    super(...arguments);
    this.args.onSetup?.(this);
  }

  updateNodeAttribute(attributeName, value) {
    if (!this.args.getPos || !this.args.view) {
      return;
    }

    // Schedule the update on the next runloop to avoid Ember tracking conflicts
    next(() => {
      const { view } = this.args;
      const pos = this.args.getPos();
      const node = view.state.doc.nodeAt(pos);

      if (!node) {
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
      const startPos = pos + 1; // Start inside the node
      const endPos = pos + node.nodeSize - 1; // End inside the node

      // Replace the content
      if (content.trim()) {
        const textNode = view.state.schema.text(content);
        tr.replaceWith(startPos, endPos, textNode);
      } else {
        // Clear content if empty
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

  get displayTime() {
    if (!this.startsAt) {
      return null;
    }

    if (this.eventData.showLocalTime) {
      return this.startsAt;
    } else {
      return this.startsAt.tz(this.userTimezone);
    }
  }

  get displayEndTime() {
    if (!this.endsAt) {
      return null;
    }

    if (this.eventData.showLocalTime) {
      return this.endsAt;
    } else {
      return this.endsAt.tz(this.userTimezone);
    }
  }

  get dateFormat() {
    return guessDateFormat(this.startsAt, this.endsAt);
  }

  get formattedStartDate() {
    return this.displayTime.format(this.dateFormat);
  }

  get hasStartDate() {
    return this.eventData.start && this.eventData.start.trim();
  }

  get hasEndDate() {
    return this.eventData.end && this.eventData.end.trim();
  }

  get hasAnyDate() {
    return this.hasStartDate || this.hasEndDate;
  }

  get formattedEndDate() {
    if (!this.displayEndTime) {
      return "";
    }
    return this.displayEndTime.format(this.dateFormat);
  }

  get formattedStartDisplay() {
    return this.displayTime.format(i18n("dates.long_no_year"));
  }

  get formattedEndDisplay() {
    if (!this.displayEndTime) {
      return i18n("discourse_post_event.composer.end_date_placeholder");
    }
    return this.displayEndTime.format(i18n("dates.long_no_year"));
  }

  get startsAtMonth() {
    if (!this.displayTime) {
      // Show current month if no start date is set
      const now = moment.tz(this.userTimezone);
      return now.format("MMM");
    }
    return this.displayTime.format("MMM");
  }

  get startsAtDay() {
    if (!this.displayTime) {
      // Show current day if no start date is set
      const now = moment.tz(this.userTimezone);
      return now.format("D");
    }
    return this.displayTime.format("D");
  }

  get statusText() {
    return i18n(
      `discourse_post_event.models.event.status.${this.eventData.status || "public"}.title`
    );
  }

  get eventName() {
    return this.eventData.name;
  }

  get eventNamePlaceholder() {
    return (
      this.composer?.get("model.title") ||
      i18n("discourse_post_event.composer.name_placeholder")
    );
  }

  get hasLocation() {
    return this.eventData.location && this.eventData.location.trim();
  }

  get isLocationUrl() {
    if (!this.hasLocation) {
      return false;
    }
    const location = this.eventData.location.trim();
    return (
      location.includes("://") ||
      location.includes("mailto:") ||
      location.startsWith("www.") ||
      /^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/.test(location)
    );
  }

  get locationIcon() {
    return this.isLocationUrl ? "link" : "location-pin";
  }

  get displayLocation() {
    if (!this.hasLocation) {
      return null;
    }
    if (this.isLocationUrl) {
      const location = this.eventData.location.trim();
      // Add protocol if missing for proper links
      if (
        location.startsWith("www.") ||
        /^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/.test(location)
      ) {
        return location.includes("://") || location.includes("mailto:")
          ? location
          : `https://${location}`;
      }
      return location;
    }
    return this.eventData.location;
  }

  get hasDescription() {
    return this.eventDescription && this.eventDescription.length > 0;
  }

  get formattedStartTime() {
    if (!this.displayTime) {
      const now = moment.tz(this.userTimezone);
      return now.format("HH:mm");
    }
    return this.displayTime.format("HH:mm");
  }

  get formattedEndTime() {
    if (!this.displayEndTime) {
      return "";
    }
    return this.displayEndTime.format("HH:mm");
  }

  formatDateTimeLocal(dateString) {
    if (!dateString) {
      return "";
    }

    const date = moment(dateString);
    if (!date.isValid()) {
      if (dateString.trim()) {
        const today = moment.tz(this.userTimezone);
        return today.format("YYYY-MM-DDTHH:mm");
      }
      return "";
    }
    return date.format("YYYY-MM-DDTHH:mm");
  }

  get formattedStartDateTime() {
    return this.formatDateTimeLocal(this.eventData.start);
  }

  get formattedEndDateTime() {
    return this.formatDateTimeLocal(this.eventData.end);
  }

  @action
  updateEventName(event) {
    event.target.value = event.target.value.replace(/\n/g, "");
    const newName = event.target.value.trim();
    this.updateNodeAttribute("name", newName);
  }

  @action
  updateEventLocation(event) {
    const newLocation = event.target.value.trim();
    this.updateNodeAttribute("location", newLocation || null);
  }

  @action
  updateEventDescription(event) {
    const newDescription = event.target.value.trim();
    this.updateNodeContent(newDescription);
  }

  @action
  updateEventStartDate(event) {
    const newDateTime = event.target.value;
    const eventTz = this.eventData.timezone || "UTC";
    if (newDateTime) {
      const dt = moment.tz(newDateTime, eventTz);
      this.updateNodeAttribute("start", dt.format("YYYY-MM-DD HH:mm"));
    } else {
      this.updateNodeAttribute(
        "start",
        moment().tz(eventTz).format("YYYY-MM-DD HH:mm")
      );
    }
  }

  @action
  updateEventEndDate(event) {
    const newDateTime = event.target.value;
    const eventTz = this.eventData.timezone || "UTC";
    if (newDateTime) {
      const dt = moment.tz(newDateTime, eventTz);
      this.updateNodeAttribute("end", dt.format("YYYY-MM-DD HH:mm"));
    } else {
      this.updateNodeAttribute("end", null);
    }
  }

  /**
   * Parses reminder string back to array format for DiscoursePostEventEvent
   * @param {string|Array} reminders - Either comma-separated string or array
   * @returns {Array} Array of reminder objects
   */
  parseReminders(reminders) {
    if (!reminders) {
      return [];
    }

    // If it's already an array, return as-is
    if (Array.isArray(reminders)) {
      return reminders;
    }

    // Parse string format: "type.value.unit,type.value.unit"
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

  /**
   * Reconstructs customFields object from individual node attributes
   * @returns {Object} Custom fields object
   */
  parseCustomFields() {
    const customFields = {};
    const allowedCustomFields =
      this.siteSettings.discourse_post_event_allowed_custom_fields
        .split("|")
        .filter(Boolean);

    // Convert each custom field back from camelCase to original name
    allowedCustomFields.forEach((fieldName) => {
      const camelCaseName = camelCase(fieldName);
      if (typeof this.eventData[camelCaseName] !== "undefined") {
        customFields[fieldName] = this.eventData[camelCaseName];
      }
    });

    return customFields;
  }

  @action
  updateEventMaxAttendees(event) {
    const newMax = parseInt(event.target.value, 10);
    const validMax = Number.isFinite(newMax) && newMax > 0 ? newMax : null;
    event.target.value = validMax || "";
    this.updateNodeAttribute("maxAttendees", validMax);
  }

  @action
  focusDateInput(event) {
    next(() => event.target.showPicker());
  }

  @action
  handleTextInputFocus(event) {
    if (this.capabilities.isIOS) {
      setTimeout(() => {
        event.target.scrollIntoView({ block: "center", behavior: "smooth" });
      }, 400);
    }
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
      reminders: this.parseReminders(this.eventData.reminders) || [],
      raw_invitees: this.eventData.allowedGroups?.split(",") || [],
      custom_fields: this.parseCustomFields(),
      starts_at: this.eventData.start
        ? moment(this.eventData.start).tz(timezone)
        : moment.tz(timezone),
      ends_at: this.eventData.end
        ? moment(this.eventData.end).tz(timezone)
        : null,
    };
  }

  @action
  openEventBuilder() {
    const eventData = this.convertNodeToEvent();

    this.modal.show(PostEventBuilder, {
      model: {
        event: DiscoursePostEventEvent.create(eventData),
        onDelete: () => {
          // Remove the event node from the document
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
          // Use buildParams to get properly formatted parameters including reminders
          const params = buildParams(
            startsAt,
            endsAt,
            event,
            this.siteSettings
          );

          // Update node attributes with the built parameters
          for (const [field, value] of Object.entries(params)) {
            if (field === "description") {
              this.updateNodeContent(value);
            } else {
              this.updateNodeAttribute(field, value);
            }
          }
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
    <header class="composer-event__header">
      <div class="composer-event__date">
        <div class="composer-event__month">{{this.startsAtMonth}}</div>
        <div class="composer-event__day">{{this.startsAtDay}}</div>
      </div>

      <div class="composer-event__info">
        <ExpandingTextArea
          rows="1"
          value={{this.eventName}}
          class="composer-event__name-input"
          placeholder={{this.eventNamePlaceholder}}
          {{on "input" this.updateEventName}}
          {{on "focus" this.handleTextInputFocus}}
        />

        <div class="composer-event__status">
          {{this.statusText}}
        </div>
      </div>

      <div class="composer-event__more-dropdown">
        <DButton
          @icon="gear"
          @action={{this.openEventBuilder}}
          @title="discourse_post_event.edit_event"
          class="btn-flat"
        />
      </div>
    </header>

    <section class="composer-event__dates">
      {{icon "clock"}}
      <div
        class="composer-event__date-range{{if
            this.hasAnyDate
            ' composer-event__date-range--has-values'
          }}"
      >
        <div class="composer-event__date-wrapper">
          <input
            type="datetime-local"
            value={{this.formattedStartDateTime}}
            class="composer-event__date-input"
            {{on "change" this.updateEventStartDate}}
            {{on "focus" this.focusDateInput}}
          />
          <span class="composer-event__date-display">
            {{this.formattedStartDisplay}}
          </span>
        </div>
        <span class="composer-event__date-separator">-</span>
        <div class="composer-event__date-wrapper">
          <input
            type="datetime-local"
            value={{this.formattedEndDateTime}}
            class="composer-event__date-input"
            {{on "change" this.updateEventEndDate}}
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
      </div>
    </section>

    <section class="composer-event__location">
      {{icon this.locationIcon}}
      <div class="composer-event__location-content">
        <input
          type="text"
          value={{this.eventData.location}}
          class="composer-event__location-input"
          placeholder={{i18n
            "discourse_post_event.composer.location_placeholder"
          }}
          {{on "input" this.updateEventLocation}}
          {{on "focus" this.handleTextInputFocus}}
        />
        {{#if this.isLocationUrl}}
          <a
            class="composer-event__location-external-link"
            href={{this.displayLocation}}
            target="_blank"
            rel="noopener noreferrer"
            title="Visit {{this.eventData.location}}"
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
        value={{this.eventData.maxAttendees}}
        placeholder={{i18n
          "discourse_post_event.composer.max_attendees_placeholder"
        }}
        class="composer-event__max-attendees-input"
        {{on "input" this.updateEventMaxAttendees}}
      />
      {{#if this.eventData.maxAttendees}}
        <span class="composer-event__max-attendees-display">
          Max
          {{this.eventData.maxAttendees}}
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
        value={{this.eventDescription}}
        rows="1"
        {{on "input" this.updateEventDescription}}
        {{on "focus" this.handleTextInputFocus}}
      />
    </section>
  </template>
}
