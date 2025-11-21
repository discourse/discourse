import { DOMParser as ProseMirrorDOMParser } from "prosemirror-model";
import { createSchema } from "../static/prosemirror/core/schema";
import Serializer from "../static/prosemirror/core/serializer";
import { getExtensions } from "./composer/rich-editor-extensions";

// Legacy callback system for backward compatibility
let tagDecorateCallbacks = [];
let blockDecorateCallbacks = [];
let textDecorateCallbacks = [];

/**
 * @deprecated Use ProseMirror extensions instead
 */
export function addTagDecorateCallback(callback) {
  tagDecorateCallbacks.push(callback);
}

export function clearTagDecorateCallbacks() {
  tagDecorateCallbacks = [];
}

/**
 * @deprecated Use ProseMirror extensions instead
 */
export function addBlockDecorateCallback(callback) {
  blockDecorateCallbacks.push(callback);
}

export function clearBlockDecorateCallbacks() {
  blockDecorateCallbacks = [];
}

/**
 * @deprecated Use ProseMirror extensions instead
 */
export function addTextDecorateCallback(callback) {
  textDecorateCallbacks.push(callback);
}

export function clearTextDecorateCallbacks() {
  textDecorateCallbacks = [];
}

export default function toMarkdown(html) {
  try {
    const extensions = getExtensions();
    const schema = createSchema(extensions);
    const domParser = ProseMirrorDOMParser.fromSchema(schema);
    const serializer = new Serializer(extensions, {});

    const element = new DOMParser().parseFromString(html, "text/html");
    const doc = domParser.parse(element);

    return serializer.convert(doc).trim();
  } catch {
    return "";
  }
}
