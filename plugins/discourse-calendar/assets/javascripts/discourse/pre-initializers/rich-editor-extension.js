import { camelize } from "@ember/string";
import { withPluginApi } from "discourse/lib/plugin-api";
import { buildEventPreview } from "../initializers/discourse-post-event-decorator";

const EVENT_ATTRIBUTES = {
  name: { default: null },
  start: { default: null },
  end: { default: null },
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
  chatChannelId: { default: null },
};

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    event: {
      attrs: EVENT_ATTRIBUTES,
      group: "block",
      defining: true,
      isolating: true,
      draggable: true,
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
      let bbcode = "[event";

      Object.entries(node.attrs).forEach(([key, value]) => {
        if (value !== null) {
          bbcode += ` ${key}="${value}"`;
        }
      });

      bbcode += "]\n[/event]\n";

      state.write(bbcode);
    },
  },
};

export default {
  initialize() {
    withPluginApi("2.1.1", (api) => {
      api.registerRichEditorExtension(extension);
    });
  },
};
