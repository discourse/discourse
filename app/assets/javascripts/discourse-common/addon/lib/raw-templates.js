import { getResolverOption } from "discourse-common/resolver";

export const __DISCOURSE_RAW_TEMPLATES = {};

export function addRawTemplate(name, template) {
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
  findOutlets(__DISCOURSE_RAW_TEMPLATES, (outletName, resource) => {
    result[outletName] = result[outletName] || [];
    result[outletName].push({
      template: __DISCOURSE_RAW_TEMPLATES[resource]
    });
  });
  return result;
}
