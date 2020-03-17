import { getResolverOption } from "discourse-common/resolver";

export function findRawTemplate(name) {
  if (getResolverOption("mobileView")) {
    return (
      Discourse.RAW_TEMPLATES[`javascripts/mobile/${name}`] ||
      Discourse.RAW_TEMPLATES[`javascripts/${name}`] ||
      Discourse.RAW_TEMPLATES[`mobile/${name}`] ||
      Discourse.RAW_TEMPLATES[name]
    );
  }

  return (
    Discourse.RAW_TEMPLATES[`javascripts/${name}`] ||
    Discourse.RAW_TEMPLATES[name]
  );
}
