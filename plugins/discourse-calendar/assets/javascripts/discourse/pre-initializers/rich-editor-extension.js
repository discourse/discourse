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

function parseAttributes(entries) {
  const attrs = {};
  const customFields = {};
  const { datasetToOriginal } = getCustomFieldConfig();

  entries.forEach(([key, value]) => {
    if (KNOWN_ATTRIBUTES.has(key)) {
      attrs[key] = value;
    } else {
      const originalName = datasetToOriginal.get(key) || key;
      customFields[originalName] = value;
    }
  });

  if (Object.keys(customFields).length > 0) {
    attrs.customFields = JSON.stringify(customFields);
  }

  return attrs;
}

function forEachCustomField(customFieldsJson, callback) {
  if (!customFieldsJson) {
    return;
  }

  try {
    const customFields = JSON.parse(customFieldsJson);
    Object.entries(customFields).forEach(([key, value]) => {
      if (value !== null) {
        callback(key, value);
      }
    });
  } catch {
    // Ignore JSON parse errors
  }
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
            return parseAttributes(Object.entries(dom.dataset));
          },
        },
      ],
      toDOM(node) {
        const element = document.createElement("div");
        element.classList.add("discourse-post-event");

        for (const [key, value] of Object.entries(node.attrs)) {
          if (value !== null && key !== "customFields") {
            element.dataset[key] = value;
          }
        }

        forEachCustomField(node.attrs.customFields, (key, value) => {
          element.dataset[getDatasetKeyForCustomField(key)] = value;
        });

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
          const entries = token.attrs
            .filter(([key]) => key.startsWith("data-"))
            .map(([key, value]) => [toDatasetKey(key.slice(5)), value]);
          state.openNode(state.schema.nodes.event, parseAttributes(entries));
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

      forEachCustomField(node.attrs.customFields, (key, value) => {
        state.write(` ${key}="${value}"`);
      });

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
