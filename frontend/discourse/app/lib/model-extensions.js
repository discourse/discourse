import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import { trackedObject, trackedSet } from "@ember/reactive/collections";
import classPrepend from "discourse/lib/class-prepend";
import {
  autoTrackedArray,
  resettableTracked,
} from "discourse/lib/tracked-tools";

const FIELD_TYPES = ["array", "object", "set"];

// Lets an instance resolve its model name at construction, before the store
// assigns `__type`.
const MODEL_NAME = Symbol("model-extension-name");

const fields = new Map(); // modelName -> Map<name, { defaultValue, type }>
const saveProperties = new Map(); // modelName -> Map<name, valueFn | undefined>
const callbacks = new Map(); // modelName -> Map<event, Array<fn>>

const CALLBACK_EVENTS = [
  "init",
  "beforeCreate",
  "afterCreate",
  "beforeUpdate",
  "afterUpdate",
  "beforeDestroy",
  "afterDestroy",
];

const CALLBACK_ALIASES = {
  beforeSave: ["beforeCreate", "beforeUpdate"],
  afterSave: ["afterCreate", "afterUpdate"],
};

function getOrCreate(map, key, factory) {
  let value = map.get(key);
  if (value === undefined) {
    value = factory();
    map.set(key, value);
  }
  return value;
}

export function stampModelClass(klass, modelName) {
  klass[MODEL_NAME] ??= modelName;
}

export function modelNameFor(instance) {
  return instance?.constructor?.[MODEL_NAME];
}

// --- Fields (tracked data properties) ---

export function registerModelField(
  modelName,
  name,
  { defaultValue, type } = {}
) {
  if (type !== undefined && !FIELD_TYPES.includes(type)) {
    throw new Error(
      `Unknown model field type: \`${type}\` (expected one of ${FIELD_TYPES.join(
        ", "
      )})`
    );
  }

  getOrCreate(fields, modelName, () => new Map()).set(name, {
    defaultValue,
    type,
  });
}

// Registered field names for a model. Merge paths (e.g. `Post#updateFromPost`)
// need them: these per-instance fields are invisible to `enumerateTrackedKeys`.
export function modelFieldNames(modelName) {
  return [...(fields.get(modelName)?.keys() ?? [])];
}

export function clearModelFields(modelName) {
  fields.delete(modelName);
}

// Per-instance tracked property, seeded via `initializer` so the default is
// applied (`tracked()` ignores a `value` descriptor and rejects it in dev).
function defineTrackedField(instance, name, value) {
  Object.defineProperty(
    instance,
    name,
    tracked(instance, name, { enumerable: true, initializer: () => value })
  );
}

// Array variant, using `autoTrackedArray` so classic `@computed` chains observe
// mutations.
function defineTrackedArrayField(instance, name, value) {
  Object.defineProperty(
    instance,
    name,
    autoTrackedArray(instance, name, { initializer: () => value })
  );
}

// Defines each registered field as a tracked property on the instance. Runs in
// `RestModel`'s constructor, before the server payload, so a server value wins.
export function applyRegisteredFields(instance) {
  const modelFields = fields.get(modelNameFor(instance));
  if (!modelFields) {
    return;
  }

  for (const [name, { defaultValue, type }] of modelFields) {
    // Function defaults run per instance; a plain value is shared across
    // instances, so mutable defaults should use a function or a `type`.
    const value =
      typeof defaultValue === "function"
        ? defaultValue.call(instance)
        : defaultValue;

    if (type === "array") {
      defineTrackedArrayField(instance, name, value);
    } else if (type === "object") {
      defineTrackedField(instance, name, trackedObject(value));
    } else if (type === "set") {
      defineTrackedField(instance, name, trackedSet(value));
    } else {
      defineTrackedField(instance, name, value);
    }
  }
}

// --- Getters, methods, and resettable fields ---
// Applied via `classPrepend`: auto-rolled-back between tests, and cleanly
// stacked on the existing class.

// Prepends a subclass defining `name` on its prototype. `describe(prototype)`
// returns the descriptor (`resettableTracked` keys off the prototype).
function definePrototypeMember(klass, name, describe) {
  classPrepend(klass, (Superclass) => {
    const Subclass = class extends Superclass {};
    Object.defineProperty(Subclass.prototype, name, {
      configurable: true,
      ...describe(Subclass.prototype),
    });
    return Subclass;
  });
}

export function defineModelAccessor(klass, name, { get, set } = {}) {
  // `@dependentKeyCompat` keeps the getter observable by classic
  // `@computed`/`@observes` consumers, so it faithfully replaces a `@computed`
  // (matches how core decorates its own native getters).
  definePrototypeMember(klass, name, (prototype) =>
    dependentKeyCompat(prototype, name, { get, set })
  );
}

export function defineModelMethod(klass, name, fn) {
  definePrototypeMember(klass, name, () => ({ writable: true, value: fn }));
}

// The field resets to `initializer`'s value whenever that value changes, while
// a manual set sticks until the next change (see `resettableTracked`).
export function defineModelResettableField(klass, name, initializer) {
  definePrototypeMember(klass, name, (proto) =>
    resettableTracked(proto, name, { initializer })
  );
}

// --- Save properties (included in the persisted payload) ---

export function registerModelSaveProperty(modelName, name, valueFn) {
  getOrCreate(saveProperties, modelName, () => new Map()).set(name, valueFn);
}

// Save-payload additions for a model's registered save properties (a `valueFn`
// overrides the plain `instance[name]`). Used by models with a custom save path.
export function extraSavePropertiesFor(modelName, instance) {
  const result = {};
  const properties = saveProperties.get(modelName);
  if (properties) {
    for (const [name, valueFn] of properties) {
      result[name] = valueFn ? valueFn.call(instance) : instance[name];
    }
  }
  return result;
}

// Merges a model's registered save properties into `props` in place. Used by
// the generic `RestModel` save path.
export function mergeSaveProperties(modelName, instance, props) {
  Object.assign(props, extraSavePropertiesFor(modelName, instance));
}

// --- Lifecycle callbacks ---

export function registerModelCallback(modelName, event, fn) {
  const events = CALLBACK_ALIASES[event] ?? [event];

  for (const resolved of events) {
    if (!CALLBACK_EVENTS.includes(resolved)) {
      throw new Error(`Unknown model callback event: \`${event}\``);
    }
  }

  const byEvent = getOrCreate(callbacks, modelName, () => new Map());
  for (const resolved of events) {
    getOrCreate(byEvent, resolved, () => []).push(fn);
  }
}

// Runs callbacks synchronously in registration order, returning a promise that
// settles once async ones do, so save paths can `await` it (`init` ignores it).
export function applyModelCallbacks(modelName, event, instance, result) {
  const fns = callbacks.get(modelName)?.get(event);
  if (!fns) {
    return;
  }

  return Promise.all(fns.map((fn) => fn.call(instance, result)));
}

// USE ONLY FOR TESTING PURPOSES.
export function resetModelExtensions() {
  fields.clear();
  saveProperties.clear();
  callbacks.clear();
}
