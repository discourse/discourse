import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import {
  buildParams,
  camelCase,
  getCustomFieldNames,
  parseEventAttrs,
  stateToEventInput,
} from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";
import CompactEventEditor from "./compact-event-editor";

const CLEARABLE_ATTRS = [
  "name",
  "location",
  "url",
  "end",
  "maxAttendees",
  "timezone",
  "recurrence",
  "recurrenceUntil",
  "showLocalTime",
  "minimal",
  "chatEnabled",
  "livestream",
  "allDay",
  "allowedGroups",
  "reminders",
  "image",
  "closed",
];

export default class EventNodeView extends Component {
  @service currentUser;
  @service siteSettings;

  constructor() {
    super(...arguments);
    this.args.onSetup?.(this);
  }

  get eventDescription() {
    return this.args.view.state.doc.textBetween(
      this.args.getPos() + 1,
      this.args.getPos() + this.args.node.nodeSize - 1,
      "\n",
      "\n"
    );
  }

  @cached
  get initialState() {
    return {
      ...parseEventAttrs(this.args.node.attrs, {
        fallbackTimezone: this.currentUser?.user_option?.timezone,
        customFieldNames: getCustomFieldNames(this.siteSettings),
      }),
      description: this.eventDescription,
    };
  }

  @action
  onChange(state) {
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

      const params = buildParams(
        state.startsAt,
        state.endsAt,
        stateToEventInput(state),
        this.siteSettings
      );
      delete params.description;

      const customFieldAttrs = getCustomFieldNames(this.siteSettings).map((f) =>
        camelCase(f)
      );
      const newAttrs = { ...node.attrs };
      for (const attr of [
        ...CLEARABLE_ATTRS,
        "start",
        "status",
        ...customFieldAttrs,
      ]) {
        newAttrs[attr] = params[attr] ?? null;
      }

      const noAttrChange = Object.keys(newAttrs).every(
        (key) => newAttrs[key] === node.attrs[key]
      );

      let tr = view.state.tr;
      if (!noAttrChange) {
        tr = tr.setNodeMarkup(pos, null, newAttrs);
      }

      const startPos = pos + 1;
      const endPos = pos + node.nodeSize - 1;
      const description = state.description || "";
      const currentDescription = this.eventDescription;
      if (description !== currentDescription) {
        if (description.trim()) {
          tr = tr.replaceWith(
            startPos,
            endPos,
            view.state.schema.text(description)
          );
        } else {
          tr = tr.delete(startPos, endPos);
        }
      }

      if (tr.docChanged) {
        view.dispatch(tr);
      }
    });
  }

  @action
  onDelete() {
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
      @initialState={{this.initialState}}
      @onChange={{this.onChange}}
      @onDelete={{this.onDelete}}
    />
  </template>
}
