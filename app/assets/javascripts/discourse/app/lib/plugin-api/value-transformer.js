import DAG from "../dag";

const transformersRegistry = new Map();
const resolvedTransformers = new Map();
const transformerLastRegisterPluginId = new Map(); // to enforce the order the transformers are registered

export function registerTransformer(
  transformerName,
  pluginId,
  transformer,
  position
) {
  if (!pluginId) {
    throw new Error("api registerTransformer requires a pluginId");
  }
  if (transformer === undefined) {
    throw new Error(
      "api registerTransformer requires transformer to be set with a value or a callback"
    );
  }
  if (position && !position.before && !position.after) {
    throw new Error(
      "api registerTransformer requires position if provided, to have a before or after key"
    );
  }

  // setting the default position to be after the last registered plugin enforces the DAG to be executed in the order
  // the plugins/theme components are registered, which provides a predictable order of execution in case a position is
  // not explicitly set
  const existingTransformers =
    transformersRegistry.get(transformerName) || new DAG();

  if (existingTransformers.has(pluginId)) {
    // eslint-disable-next-line no-console
    console.warn(
      `Value transformer ${transformerName} already registered previously with pluginId ${pluginId}`
    );
    existingTransformers.delete(pluginId);
  }

  existingTransformers.add(
    pluginId,
    transformer,
    position || {
      after:
        transformerLastRegisterPluginId.get(pluginId) || "__discourse:core",
    }
  );

  transformersRegistry.set(transformerName, existingTransformers);

  // just updated the last registered plugin id, if a position is not provided, or else we can bind the next transformer
  // with the position specified
  if (!position) {
    transformerLastRegisterPluginId.set(pluginId);
  }

  // resolve the transformers DAG to cache the result and avoid resolving it every time the value transformer is used
  resolveTransformersDag(transformerName);
}

export function applyTransformer(transformerName, value, context) {
  const transformers = resolvedTransformers.get(transformerName);
  if (!transformers) {
    return value;
  }

  let newValue = value;

  for (const entry of transformers) {
    const { value: transformer } = entry;

    if (typeof transformer === "function") {
      newValue = transformer(newValue, context);
    } else {
      newValue = transformer;
    }
  }

  return newValue;
}

function resolveTransformersDag(transformerName) {
  const transformersDag = transformersRegistry.get(transformerName);

  if (!transformersDag) {
    resolvedTransformers.delete(transformerName);
    return;
  }

  resolvedTransformers.set(transformerName, transformersDag.resolve());
}
