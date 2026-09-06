import { trackedObject } from "@ember/reactive/collections";

// Legacy `RestModel` kept whatever the server sent. A WarpDrive cache only
// keeps what the schema declares, and core's schemas can't know about the
// attributes plugins add (`add_to_serializer`) or the ad-hoc keys callers pass
// to `create`. Those are retained here instead of being dropped, keyed by
// identity so every wrapper around the same cached record reads the same
// values.
const registry = new Map();

function keyFor(type, id) {
  return `${type}:${id}`;
}

export function recordExtraAttributes(type, id, attributes) {
  if (Object.keys(attributes).length === 0) {
    return;
  }

  const key = keyFor(type, id);
  let stored = registry.get(key);
  if (!stored) {
    stored = trackedObject({});
    registry.set(key, stored);
  }

  Object.assign(stored, attributes);
}

export function extraAttributesFor(type, id) {
  return registry.get(keyFor(type, id));
}

// Exposes `attributes` as own accessors on `target`. Names that already resolve
// (a schema forwarder, a getter, a method) win and are left alone. Defining
// accessors rather than copying values keeps later payloads visible: they land
// in the same `attributes` object.
export function exposeExtraAttributes(target, attributes) {
  for (const name of Object.keys(attributes)) {
    if (name in target) {
      continue;
    }

    Object.defineProperty(target, name, {
      configurable: true,
      enumerable: true,
      get: () => attributes[name],
      set: (value) => {
        attributes[name] = value;
      },
    });
  }
}

// USE ONLY FOR TESTING PURPOSES.
export function clearExtraAttributes() {
  registry.clear();
}
