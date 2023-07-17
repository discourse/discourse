import { getResolverOption } from "discourse-common/resolver";
import require from "require";

export const __DISCOURSE_RAW_TEMPLATES = {};

export function addRawTemplate(name, template, opts = {}) {
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

export function buildRawConnectorCache(findOutlets) {
  let result = {};
  findOutlets(
    Object.keys(__DISCOURSE_RAW_TEMPLATES),
    (outletName, resource) => {
      result[outletName] ??= [];
      result[outletName].push({
        template: __DISCOURSE_RAW_TEMPLATES[resource],
      });
    }
  );
  return result;
}

export function eagerLoadRawTemplateModules() {
  for (const key of Object.keys(requirejs.entries)) {
    if (key.includes("/raw-templates/")) {
      require(key);
    }
  }
}
