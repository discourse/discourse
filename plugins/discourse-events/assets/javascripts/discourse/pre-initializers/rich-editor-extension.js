import { withPluginApi } from "discourse/lib/plugin-api";
import { buildBBCodeAttrs } from "discourse/lib/text";
import DiscoursePostEventOneboxNodeView, {
  topicIdFromUrl,
} from "../components/discourse-post-event/onebox-node-view";
import EventNodeView from "../components/event-node-view";
import { buildEventPreview } from "../lib/event-preview";
import {
  buildEventSkeleton,
  camelCase,
  getCustomFieldNames,
} from "../lib/raw-event-helper";

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
  livestream: { default: null },
  allDay: { default: null },
  image: { default: null },
};

/** @returns {RichEditorExtension} */
const buildExtension = (siteSettings) => ({
  nodeViews: {
    event: {
      component: EventNodeView,
    },
    // render event-topic oneboxes as the read-only event card; non-event topic
    // oneboxes (shouldRender false) keep the default onebox rendering
    ...(siteSettings.discourse_post_event_enabled && {
      onebox: {
        component: DiscoursePostEventOneboxNodeView,
        shouldRender: ({ node }) => topicIdFromUrl(node.attrs.url) !== null,
      },
    }),
  },

  nodeSpec: {
    event: {
      get attrs() {
        const attrs = { ...EVENT_ATTRIBUTES };
        getCustomFieldNames(siteSettings).forEach((field) => {
          attrs[camelCase(field)] = { default: null };
        });
        return attrs;
      },
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
              .map(([key, value]) => [camelCase(key.slice(5)), value])
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
      const userInput = match[1].trim();
      const eventMarkdown = userInput
        ? `[event ${userInput}]\n[/event]`
        : buildEventSkeleton(getContext().currentUser);

      const doc = convertFromMarkdown(eventMarkdown);
      return doc.content.firstChild
        ? state.tr.replaceWith(start, end, doc.content.firstChild)
        : null;
    },
  }),
});

export default {
  initialize() {
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      api.registerRichEditorExtension(buildExtension(siteSettings));
    });
  },
};
