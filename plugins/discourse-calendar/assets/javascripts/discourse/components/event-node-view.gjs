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
import { buildParams } from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";

/**
 * Rich event preview component for the ProseMirror editor
 * Shows event information with inline editing capabilities matching the main event design
 * @component EventNodeView
 */
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

  /**
   * Updates a node attribute using ProseMirror's setNodeMarkup
   * @param {string} attributeName - The attribute to update
   * @param {*} value - The new value for the attribute
   */
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

  /**
   * Updates the node's content (used for description)
   * @param {string} content - The new content
   */
  updateNodeContent(content) {
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
    // Description is stored in the node's content, not as an attribute
    if (!this.args.node || !this.args.node.content) {
      return "";
    }

    let description = "";
    this.args.node.content.forEach((child) => {
      if (child.type.name === "paragraph") {
        // Extract text from paragraph nodes
        child.content?.forEach((textNode) => {
          if (textNode.type.name === "text") {
            description += textNode.text;
          }
        });
        description += "\n"; // Add newline between paragraphs
      } else if (child.type.name === "text") {
        // Handle direct text nodes as fallback
        description += child.text;
      }
    });

    return description.trim();
  }

  get startsAt() {
    if (!this.eventData.start) {
      return null;
    }

    return moment.tz(this.eventData.start, this.eventData.timezone || "UTC");
  }

  get endsAt() {
    if (!this.eventData.end) {
      return null;
    }

    return moment.tz(this.eventData.end, this.eventData.timezone || "UTC");
  }

  get displayTime() {
    if (!this.startsAt) {
      return null;
    }

    if (this.eventData.showLocalTime) {
      return this.startsAt;
    } else {
      return this.startsAt.tz(
        this.currentUser?.user_option?.timezone || moment.tz.guess()
      );
    }
  }

  get displayEndTime() {
    if (!this.endsAt) {
      return null;
    }

    if (this.eventData.showLocalTime) {
      return this.endsAt;
    } else {
      return this.endsAt.tz(
        this.currentUser?.user_option?.timezone || moment.tz.guess()
      );
    }
  }

  get dateFormat() {
    return guessDateFormat(this.startsAt, this.endsAt);
  }

  get formattedStartDate() {
    if (!this.displayTime) {
      return "Set start date";
    }
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

  get datesText() {
    let text = this.formattedStartDate;
    if (this.formattedEndDate) {
      text += ` → ${this.formattedEndDate}`;
    }
    return text;
  }

  get formattedStartDisplay() {
    if (!this.displayTime) {
      return "Set start date";
    }
    return this.displayTime.format(i18n("dates.long_no_year"));
  }

  get formattedEndDisplay() {
    if (!this.displayEndTime) {
      return "Set end date";
    }
    return this.displayEndTime.format(i18n("dates.long_no_year"));
  }

  get startsAtMonth() {
    if (!this.displayTime) {
      // Show current month if no start date is set
      const now = moment.tz(
        this.currentUser?.user_option?.timezone || moment.tz.guess()
      );
      return now.format("MMM");
    }
    return this.displayTime.format("MMM");
  }

  get startsAtDay() {
    if (!this.displayTime) {
      // Show current day if no start date is set
      const now = moment.tz(
        this.currentUser?.user_option?.timezone || moment.tz.guess()
      );
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
    return this.composer?.get("model.title") || "Event";
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

  get locationPlaceholder() {
    return "Add location or URL";
  }

  get locationEditTitle() {
    return this.isLocationUrl
      ? "Click to edit location or URL"
      : "Click to edit location";
  }

  get hasDescription() {
    return this.eventDescription && this.eventDescription.length > 0;
  }

  get canEditDate() {
    return true; // Always allow date editing with smart defaults
  }

  get formattedStartTime() {
    if (!this.displayTime) {
      // Default to current time if no start time is set
      const now = moment.tz(
        this.currentUser?.user_option?.timezone || moment.tz.guess()
      );
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

  get showEndDate() {
    return true;
  }

  get formattedStartDateTime() {
    if (!this.eventData.start) {
      return "";
    }
    const dt = moment(this.eventData.start);
    return dt.format("YYYY-MM-DDTHH:mm");
  }

  get formattedEndDateTime() {
    if (!this.eventData.end) {
      return "";
    }
    const dt = moment(this.eventData.end);
    return dt.format("YYYY-MM-DDTHH:mm");
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
    if (newDateTime) {
      const dt = moment(newDateTime);
      this.updateNodeAttribute("start", dt.toISOString());
    } else {
      this.updateNodeAttribute("start", null);
    }
  }

  @action
  updateEventEndDate(event) {
    const newDateTime = event.target.value;
    if (newDateTime) {
      const dt = moment(newDateTime);
      this.updateNodeAttribute("end", dt.toISOString());
    } else {
      this.updateNodeAttribute("end", null);
    }
  }

  @action
  focusDatePlaceholder() {
    // Focus the first datetime input when placeholder is clicked
    const startInput = document.querySelector(
      '.composer-event-node input[type="datetime-local"]:first-of-type'
    );
    if (startInput) {
      startInput.focus();
    }
  }

  updateDateTime(field, dateString, timeString) {
    if (!dateString || !timeString) {
      this.updateNodeAttribute(field, null);
      return;
    }

    const timezone =
      this.eventData.timezone ||
      this.currentUser?.user_option?.timezone ||
      moment.tz.guess();
    const combined = moment.tz(`${dateString} ${timeString}`, timezone);

    if (combined.isValid()) {
      this.updateNodeAttribute(field, combined.toISOString());
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
      const camelCaseName = this.camelCase(fieldName);
      if (typeof this.eventData[camelCaseName] !== "undefined") {
        customFields[fieldName] = this.eventData[camelCaseName];
      }
    });

    return customFields;
  }

  /**
   * Converts string to camelCase (matches the logic in raw-event-helper.js)
   * @param {string} input - The string to convert
   * @returns {string} camelCase string
   */
  camelCase(input) {
    return input
      .toLowerCase()
      .replace(/-/g, "_")
      .replace(/_(.)/g, (match, group1) => group1.toUpperCase());
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
    event.target.showPicker();
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
  openEventBuilder() {
    // Create an event object from the current node data
    const eventData = {
      name: this.eventData.name,
      location: this.eventData.location,
      description: this.eventDescription,
      timezone: this.eventData.timezone || "UTC",
      status: this.eventData.status || "public",
      maxAttendees: this.eventData.maxAttendees,
      showLocalTime: this.eventData.showLocalTime,
      chatEnabled: this.eventData.chatEnabled,
      minimal: this.eventData.minimal,
      reminders: this.parseReminders(this.eventData.reminders) || [],
      rawInvitees: this.eventData.allowedGroups
        ? this.eventData.allowedGroups.split(",")
        : [],
      customFields: this.parseCustomFields(),
    };

    // Set starts_at and ends_at if they exist
    if (this.eventData.start) {
      eventData.starts_at = moment(this.eventData.start).tz(eventData.timezone);
    } else {
      // Default to current time if no start date set
      eventData.starts_at = moment.tz(eventData.timezone);
    }

    if (this.eventData.end) {
      eventData.ends_at = moment(this.eventData.end).tz(eventData.timezone);
    }

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

        <div class="composer-event__status-and-creators">
          {{#if this.statusText}}
            <span class="composer-event__status">{{this.statusText}}</span>
          {{/if}}

          {{#if this.eventData.chatEnabled}}
            <span class="composer-event__separator">·</span>
            <span class="composer-event__chat-indicator">💬 Chat</span>
          {{/if}}
        </div>
      </div>

      <div class="composer-event__more-dropdown">
        <DButton
          @icon="gear"
          @action={{this.openEventBuilder}}
          @title="Event options"
          class="btn-flat"
        />
      </div>
    </header>

    {{#if this.canEditDate}}
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
          <span class="composer-event__date-separator">→</span>
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
    {{/if}}

    <section class="composer-event__location">
      {{icon this.locationIcon}}
      <div class="composer-event__location-content">
        <input
          type="text"
          value={{this.eventData.location}}
          class="composer-event__location-input"
          placeholder={{this.locationPlaceholder}}
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
        value=""
        placeholder="Set max attendees"
        class="composer-event__max-attendees-input"
        {{on "input" this.updateEventMaxAttendees}}
      />
      {{#if this.eventData.maxAttendees}}
        <span class="composer-event__max-attendees-display">Max
          {{this.eventData.maxAttendees}}
          attendees</span>
      {{/if}}
    </section>

    <section class="composer-event__description">
      <ExpandingTextArea
        class="composer-event__description-textarea"
        placeholder="Add event description"
        rows="1"
        {{on "input" this.updateEventDescription}}
        {{on "focus" this.handleTextInputFocus}}
      >{{this.eventDescription}}</ExpandingTextArea>
    </section>
  </template>
}
