import {
  initSync,
  Preprocessor,
} from "./node_modules/content-tag/pkg/standalone/content_tag.js";
import contentTagWasm from "./node_modules/content-tag/pkg/standalone/content_tag_bg.wasm";

let preprocessor;

// We defer this, because v8 snapshots don't have
// access to the WebAssembly module at snapshot time.
export function getPreprocessor() {
  if (preprocessor) {
    return preprocessor;
  }
  initSync({ module: contentTagWasm });
  return (preprocessor = new Preprocessor());
}
