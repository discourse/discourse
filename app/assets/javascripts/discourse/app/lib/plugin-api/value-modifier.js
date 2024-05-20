import DAG from "../dag";

const modifiersRegistry = new Map();
const resolvedModifiers = new Map();
const modifierLastRegisterPluginId = new Map(); // to enforce the order the modifiers are registered

export function registerValueModifier(
  modifierName,
  pluginId,
  valueModifier,
  position
) {
  if (!pluginId) {
    throw new Error("api registerValueModifier requires a pluginId");
  }
  if (valueModifier === undefined) {
    throw new Error(
      "api registerValueModifier requires valueModifier to be set with a value or a callback"
    );
  }
  if (position && !position.before && !position.after) {
    throw new Error(
      "api registerValueModifier requires position if provided, to have a before or after key"
    );
  }

  // setting the default position to be after the last registered plugin enforces the DAG to be executed in the order
  // the plugins/theme components are registered, which provides a predictable order of execution in case a position is
  // not explicitly set
  const existingModifiers = modifiersRegistry.get(modifierName) || new DAG();

  if (existingModifiers.has(pluginId)) {
    // eslint-disable-next-line no-console
    console.warn(
      `Value modifier ${modifierName} already registered previously with pluginId ${pluginId}`
    );
    existingModifiers.delete(pluginId);
  }

  existingModifiers.add(
    pluginId,
    valueModifier,
    position || {
      after: modifierLastRegisterPluginId.get(pluginId) || "__discourse:core",
    }
  );

  modifiersRegistry.set(modifierName, existingModifiers);

  // just updated the last registered plugin id, if a position is not provided, or else we can bind the next modifier
  // with the position specified
  if (!position) {
    modifierLastRegisterPluginId.set(pluginId);
  }

  // resolve the modifiers DAG to cache the result and avoid resolving it every time the value modifier is used
  resolveModifiersDag(modifierName);
}

export function applyValueModifier(modifierName, value, context) {
  const modifiers = resolvedModifiers.get(modifierName);
  if (!modifiers) {
    return value;
  }

  let newValue = value;

  for (const entry of modifiers) {
    const { value: valueModifier } = entry;

    if (typeof valueModifier === "function") {
      newValue = valueModifier(newValue, context);
    } else {
      newValue = valueModifier;
    }
  }

  return newValue;
}

function resolveModifiersDag(modifierName) {
  const modifiersDag = modifiersRegistry.get(modifierName);

  if (!modifiersDag) {
    resolvedModifiers.delete(modifierName);
    return;
  }

  resolvedModifiers.set(modifierName, modifiersDag.resolve());
}
