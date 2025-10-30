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
  customFields: { default: null },
};

const KNOWN_ATTRIBUTES = new Set(Object.keys(EVENT_ATTRIBUTES));
let siteSettings;
let cachedCustomFieldSetting;
let cachedCustomFieldConfig;

function getCustomFieldConfig() {
  const setting =
    siteSettings?.discourse_post_event_allowed_custom_fields ?? "";

  if (cachedCustomFieldConfig && cachedCustomFieldSetting === setting) {
    return cachedCustomFieldConfig;
  }

  const datasetToOriginal = new Map();
  const originalToDataset = new Map();

  setting
    .split("|")
    .map((field) => field.trim())
    .filter(Boolean)
    .forEach((field) => {
      const datasetKey = toDatasetKey(field);
      if (!datasetToOriginal.has(datasetKey)) {
        datasetToOriginal.set(datasetKey, field);
      }
      if (!originalToDataset.has(field)) {
        originalToDataset.set(field, datasetKey);
      }
    });

  cachedCustomFieldSetting = setting;
  cachedCustomFieldConfig = {
    datasetToOriginal,
    originalToDataset,
  };

  return cachedCustomFieldConfig;
}

function toDatasetKey(fieldName) {
  if (!fieldName) {
    return fieldName;
  }

  const normalized = fieldName
    .replace(/[-_]+([a-zA-Z0-9])/g, (_, char) => char.toUpperCase())
    .replace(/\s+/g, "");

  return normalized.charAt(0).toLowerCase() + normalized.slice(1);
}

function getDatasetKeyForCustomField(fieldName) {
  return (
    getCustomFieldConfig().originalToDataset.get(fieldName) ||
    toDatasetKey(fieldName)
  );
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    event: {
      attrs: EVENT_ATTRIBUTES,
      group: "block",
      content: "block*",
      defining: true,
      isolating: true,
      draggable: true,
      parseDOM: [
        {
          tag: "div.discourse-post-event",
          getAttrs(dom) {
            const attrs = {};
            const customFields = {};
            const { datasetToOriginal } = getCustomFieldConfig();

            // Separate known attributes from custom fields
            for (const [key, value] of Object.entries(dom.dataset)) {
              if (KNOWN_ATTRIBUTES.has(key)) {
                attrs[key] = value;
                continue;
              }

              const originalName = datasetToOriginal.get(key) || key;
              customFields[originalName] = value;
            }

            if (Object.keys(customFields).length > 0) {
              attrs.customFields = JSON.stringify(customFields);
            }

            return attrs;
          },
        },
      ],
      toDOM(node) {
        const element = document.createElement("div");
        element.classList.add("discourse-post-event");

        // Add known attributes
        for (const [key, value] of Object.entries(node.attrs)) {
          if (value !== null && key !== "customFields") {
            element.dataset[key] = value;
          }
        }

        // Add custom fields
        if (node.attrs.customFields) {
          try {
            const customFields = JSON.parse(node.attrs.customFields);
            for (const [key, value] of Object.entries(customFields)) {
              if (value !== null) {
                const datasetKey = getDatasetKeyForCustomField(key);
                element.dataset[datasetKey] = value;
              }
            }
          } catch {
            // Ignore JSON parse errors
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
          const attrs = {};
          const customFields = {};
          const { datasetToOriginal } = getCustomFieldConfig();

          token.attrs
            .filter(([key]) => key.startsWith("data-"))
            .forEach(([key, value]) => {
              const dataKey = key.slice(5);
              const datasetKey = toDatasetKey(dataKey);

              if (KNOWN_ATTRIBUTES.has(datasetKey)) {
                attrs[datasetKey] = value;
                return;
              }

              const originalName = datasetToOriginal.get(datasetKey) || dataKey;
              customFields[originalName] = value;
            });

          if (Object.keys(customFields).length > 0) {
            attrs.customFields = JSON.stringify(customFields);
          }

          state.openNode(state.schema.nodes.event, attrs);
          return true;
        }
      }

      return false;
    },
  },

  serializeNode: {
    event(state, node) {
      state.write("[event");

      Object.entries(node.attrs).forEach(([key, value]) => {
        if (value !== null && key !== "customFields") {
          state.write(` ${key}="${value}"`);
        }
      });

      if (node.attrs.customFields) {
        try {
          const customFields = JSON.parse(node.attrs.customFields);
          Object.entries(customFields).forEach(([key, value]) => {
            if (value !== null) {
              state.write(` ${key}="${value}"`);
            }
          });
        } catch {
          // Ignore JSON parse errors
        }
      }

      state.write("]\n");

      if (node.content.size > 0) {
        state.renderContent(node);
      }

      state.write("[/event]\n");
    },
  },
};

export default {
  initialize() {
    withPluginApi((api) => {
      siteSettings = api.container.lookup("service:site-settings");
      cachedCustomFieldSetting = undefined;
      cachedCustomFieldConfig = undefined;
      api.registerRichEditorExtension(extension);
    });
  },
};
