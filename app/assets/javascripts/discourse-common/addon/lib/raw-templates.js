import require from "require";
import { getResolverOption } from "discourse-common/resolver";

export const __DISCOURSE_RAW_TEMPLATES = {};
export let _needsHbrTopicList = false;

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

export function addRawTemplate(name, template, opts = {}) {
  if (!opts.core && !opts.hasModernReplacement) {
    // TODO: check for hbr connectors
    _needsHbrTopicList = true;
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
