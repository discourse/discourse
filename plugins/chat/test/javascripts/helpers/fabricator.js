import { cloneJSON } from "discourse-common/lib/object";

// heavily inspired by https://github.com/travelperk/fabricator
export function Fabricator(Model, attributes = {}) {
  return (opts) => fabricate(Model, attributes, opts);
}

function fabricate(Model, attributes, opts = {}) {
  if (typeof attributes === "function") {
    return attributes();
  }

  const extendedModel = cloneJSON({ ...attributes, ...opts });
  const props = {};

  for (const [key, value] of Object.entries(extendedModel)) {
    props[key] = typeof value === "function" ? value() : value;
  }

  return Model.create(props);
}
