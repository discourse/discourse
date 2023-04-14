import { consolePrefix } from "discourse/lib/source-identifier";

let modelTransformersMap = {};

export function registerModelTransformer(modelName, func) {
  if (!modelTransformersMap[modelName]) {
    modelTransformersMap[modelName] = [];
  }
  const transformer = {
    prefix: consolePrefix(),
    execute: func,
  };
  modelTransformersMap[modelName].push(transformer);
}

export async function applyModelTransformations(modelName, models) {
  for (const transformer of modelTransformersMap[modelName] || []) {
    try {
      await transformer.execute(models);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(
        transformer.prefix,
        `transformer for the \`${modelName}\` model failed with:`,
        err,
        err.stack
      );
    }
  }
}

export function resetModelTransformers() {
  modelTransformersMap = {};
}
