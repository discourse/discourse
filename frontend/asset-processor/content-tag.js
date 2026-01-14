import {
  initSync,
  Preprocessor,
} from "./node_modules/content-tag/pkg/standalone/content_tag.js";
import contentTagWasm from "./node_modules/content-tag/pkg/standalone/content_tag_bg.wasm";

export { Preprocessor };

initSync({ module: contentTagWasm });
