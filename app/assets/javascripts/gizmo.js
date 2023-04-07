const processor = require("./discourse-js-processor");

// Make interfaces available via `v8.call`
globalThis.compileRawTemplate = processor.compileRawTemplate;
globalThis.transpile = processor.transpile;
globalThis.minify = processor.minify;
globalThis.getMinifyResult = processor.getMinifyResult;
