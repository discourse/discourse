import { buildEngine } from "discourse/static/markdown-it";

let engine;

function getEngine() {
  engine ??= buildEngine();

  return engine;
}

export const parse = (text) => getEngine().parse(text);

export const getLinkify = () => getEngine().linkify;

export const isWhiteSpace = (str, index) =>
  !str || getEngine().options.engine.utils.isWhiteSpace(str.charCodeAt(index));

export const isBoundary = (str, index) =>
  !str ||
  getEngine().options.engine.utils.isWhiteSpace(str.charCodeAt(index)) ||
  getEngine().options.engine.utils.isPunctChar(
    String.fromCharCode(str.charCodeAt(index))
  );
