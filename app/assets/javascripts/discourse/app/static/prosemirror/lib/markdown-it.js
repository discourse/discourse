import { buildEngine } from "discourse/static/markdown-it";
import loadPluginFeatures from "discourse/static/markdown-it/features";
import defaultFeatures from "discourse-markdown-it/features/index";

let engine;

function getEngine() {
  engine ??= buildEngine({
    featuresOverride: [...defaultFeatures, ...loadPluginFeatures()]
      .map(({ id }) => id)
      // Avoid oneboxing when parsing, we'll handle that separately
      .filter((id) => id !== "onebox"),
  });

  return engine;
}

export const parse = (text) => getEngine().parse(text);

export const getLinkify = () => getEngine().linkify;

export const isBoundary = (str, index) =>
  getEngine().options.engine.utils.isWhiteSpace(str.charCodeAt(index)) ||
  getEngine().options.engine.utils.isPunctChar(
    String.fromCharCode(str.charCodeAt(index))
  );
