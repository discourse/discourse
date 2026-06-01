import { fileURLToPath } from "node:url";
import { rolldown } from "rolldown";

const local = (p) => fileURLToPath(import.meta.resolve(p));

const bundle = await rolldown({
  input: local("./transpiler.js"),
  platform: "browser",
  moduleTypes: { ".wasm": "binary" },
  transform: {
    define: {
      "import.meta.url": "'http://example.com'",
    },
  },
  resolve: {
    alias: {
      path: "path-browserify",
      url: local("./url-polyfill.js"),
      "source-map-js": "source-map-js",
      assert: local("./noop.js"),
      fs: local("./noop.js"),
      stream: "readable-stream",
      "abort-controller": "abort-controller/dist/abort-controller",
      os: local("./os-shim.js"),
      workerpool: local("./workerpool-shim.js"),
    },
  },
  plugins: [
    {
      name: "text-encoder-umd",
      transform: {
        filter: { id: /EncoderDecoderTogether\.min\.js$/ },
        // Give this UMD a local `self` to attach its exports to, then re-export them.
        handler(code) {
          return {
            code: `var self = {};\n${code}\nexport const { TextEncoder, TextDecoder } = self;\n`,
            moduleType: "js",
          };
        },
      },
    },
  ],
});

const { output } = await bundle.generate({
  format: "iife",
  minify: false,
  banner: `var process = { "env": { "EMBER_ENV": "production" }, "cwd": () => "/" };`,
});

await bundle.close();

process.stdout.write(output[0].code);
