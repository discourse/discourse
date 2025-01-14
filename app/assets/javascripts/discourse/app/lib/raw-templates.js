import require from "require";
import deprecated from "discourse/lib/deprecated";
import { RAW_TOPIC_LIST_DEPRECATION_OPTIONS } from "discourse/lib/plugin-api";
import { getResolverOption } from "discourse/resolver";

export const __DISCOURSE_RAW_TEMPLATES = {};
let _needsHbrTopicList = false;

export function needsHbrTopicList(value) {
  if (value === undefined) {
    return _needsHbrTopicList;
  } else {
    _needsHbrTopicList = value;
  }
}

export function resetNeedsHbrTopicList() {
  _needsHbrTopicList = false;
}

const TOPIC_LIST_TEMPLATE_NAMES = [
  "list/action-list",
  "list/activity-column",
  "list/category-column",
  "list/new-list-header-controls",
  "list/participant-groups",
  "list/post-count-or-badges",
  "list/posters-column",
  "list/posts-count-column",
  "list/topic-excerpt",
  "list/topic-list-item",
  "list/unread-indicator",
  "list/visited-line",
  "mobile/list/topic-list-item",
  "topic-bulk-select-dropdown",
  "topic-list-header-column",
  "topic-list-header",
  "topic-post-badges",
  "topic-status",
];

export function addRawTemplate(name, template, opts = {}) {
  const cleanName = name.replace(/^javascripts\//, "");
  if (
    (TOPIC_LIST_TEMPLATE_NAMES.includes(cleanName) ||
      name.includes("/connectors/")) &&
    !opts.core &&
    !opts.hasModernReplacement
  ) {
    const message = `[${name}] hbr topic-list template overrides and connectors are deprecated. Use the value transformer \`topic-list-columns\` and other new topic-list plugin APIs instead.`;

    // NOTE: addRawTemplate is called too early for deprecation handlers to process this:
    deprecated(message, RAW_TOPIC_LIST_DEPRECATION_OPTIONS);

    needsHbrTopicList(true);
  }

  // Core templates should never overwrite themes / plugins
  if (opts.core && __DISCOURSE_RAW_TEMPLATES[name]) {
    return;
  }
  __DISCOURSE_RAW_TEMPLATES[name] = template;
}

export function removeRawTemplate(name) {
  delete __DISCOURSE_RAW_TEMPLATES[name];
}

export function findRawTemplate(name) {
  if (getResolverOption("mobileView")) {
    return (
      __DISCOURSE_RAW_TEMPLATES[`javascripts/mobile/${name}`] ||
      __DISCOURSE_RAW_TEMPLATES[`javascripts/${name}`] ||
      __DISCOURSE_RAW_TEMPLATES[`mobile/${name}`] ||
      __DISCOURSE_RAW_TEMPLATES[name]
    );
  }

  return (
    __DISCOURSE_RAW_TEMPLATES[`javascripts/${name}`] ||
    __DISCOURSE_RAW_TEMPLATES[name]
  );
}

export function buildRawConnectorCache() {
  let result = {};
  Object.keys(__DISCOURSE_RAW_TEMPLATES).forEach((resource) => {
    const segments = resource.split("/");
    const connectorIndex = segments.indexOf("connectors");

    if (connectorIndex >= 0) {
      const outletName = segments[connectorIndex + 1];
      result[outletName] ??= [];
      result[outletName].push({
        template: __DISCOURSE_RAW_TEMPLATES[resource],
      });
    }
  });
  return result;
}

export function eagerLoadRawTemplateModules() {
  for (const key of Object.keys(requirejs.entries)) {
    if (key.includes("/raw-templates/")) {
      require(key);
    }
  }
}
