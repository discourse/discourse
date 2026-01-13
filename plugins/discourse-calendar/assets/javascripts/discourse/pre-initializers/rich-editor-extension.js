import { camelize } from "@ember/string";
import { withPluginApi } from "discourse/lib/plugin-api";
import { buildBBCodeAttrs } from "discourse/lib/text";
import EventNodeView from "../components/event-node-view";
import { buildEventPreview } from "../initializers/discourse-post-event-decorator";

export const EVENT_ATTRIBUTES = {
  name: { default: null },
  start: { default: null },
  end: { default: null },
  location: { default: null },
  maxAttendees: { default: null },
  reminders: { default: null },
  minimal: { default: null },
  closed: { default: null },
  status: { default: "public" },
  timezone: { default: "UTC" },
  showLocalTime: { default: null },
  allowedGroups: { default: null },
  recurrence: { default: null },
  recurrenceUntil: { default: null },
  chatEnabled: { default: null },
};

/** @type {RichEditorExtension} */
const extension = {
  nodeViews: {
    event: {
      component: EventNodeView,
      name: "event",
    },
  },

  nodeSpec: {
    event: {
      attrs: EVENT_ATTRIBUTES,
      group: "block",
      content: "block*",
      defining: true,
      isolating: true,
      parseDOM: [
        {
          tag: "div.discourse-post-event",
          getAttrs(dom) {
            return { ...dom.dataset };
          },
        },
      ],
      toDOM(node) {
        const element = document.createElement("div");
        element.classList.add("discourse-post-event");
        for (const [key, value] of Object.entries(node.attrs)) {
          if (value !== null) {
            element.dataset[key] = value;
          }
        }

        buildEventPreview(element);

        return element;
      },
    },
  },

  parse: {
    wrap_bbcode(state, token) {
      if (token.tag === "div") {
        if (token.nesting === -1 && state.top().type.name === "event") {
          state.closeNode();
          return true;
        }

        if (
          token.nesting === 1 &&
          token.attrGet("class") === "discourse-post-event"
        ) {
          const attrs = Object.fromEntries(
            token.attrs
              .filter(([key]) => key.startsWith("data-"))
              .map(([key, value]) => [camelize(key.slice(5)), value])
          );

          state.openNode(state.schema.nodes.event, attrs);
          return true;
        }
      }

      return false;
    },
  },

  serializeNode: {
    event(state, node) {
      const attrs = buildBBCodeAttrs(node.attrs);
      state.write(`[event${attrs ? ` ${attrs}` : ""}]\n`);

      if (node.content.size > 0) {
        state.renderContent(node);
      }

      state.write("[/event]\n");
    },
  },
  inputRules: ({ utils: { convertFromMarkdown }, getContext }) => ({
    match: /^\[event([^\]]*)]$/,
    handler: (state, match, start, end) => {
      const currentUser = getContext().currentUser;
      const timezone = currentUser?.user_option?.timezone || moment.tz.guess();

      const userInput = match[1].trim();
      let eventMarkdown;

      if (userInput) {
        eventMarkdown = `[event ${userInput}]\n[/event]`;
      } else {
        const now = moment.tz(moment(), timezone);
        const defaults = `start="${now.format("YYYY-MM-DD HH:mm")}" status="public" timezone="${timezone}"`;
        eventMarkdown = `[event ${defaults}]\n[/event]`;
      }

      const doc = convertFromMarkdown(eventMarkdown);
      return doc.content.firstChild
        ? state.tr.replaceWith(start, end, doc.content.firstChild)
        : null;
    },
  }),
};

export default {
  initialize() {
    withPluginApi((api) => {
      api.registerRichEditorExtension(extension);
    });
  },
};
