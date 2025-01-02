// import { JSDOM } from "jsdom";
import "core-js/actual/url";
import patch from "./text-decoder-shim";
patch();

import { rollup } from "/Users/david/discourse/rollup/browser/dist/es/rollup.browser.js";
const CONSOLE_PREFIX = "[DiscourseJsProcessor] ";
// globalThis.window = {};

const oldConsole = globalThis.console;
globalThis.console = {
  log(...args) {
    globalThis.rails?.logger.info(CONSOLE_PREFIX + args.join(" "));
    oldConsole.log(...args);
  },
  warn(...args) {
    globalThis.rails?.logger.warn(CONSOLE_PREFIX + args.join(" "));
    oldConsole.warn(...args);
  },
  error(...args) {
    globalThis.rails?.logger.error(CONSOLE_PREFIX + args.join(" "));
    oldConsole.error(...args);
  },
};

globalThis.crypto = {
  getRandomValues() {
    // todo... not much random going on here
    console.log("getRandomValues");
  },
};

// console.log(TextDecoder);
import BindingsWasm from "/Users/david/discourse/rollup/browser/dist/bindings_wasm_bg.wasm";
// import BindingsWasm from "./node_modules/@rollup/wasm-node/dist/wasm-node/bindings_wasm_bg.wasm";
// import BindingsWasm from "./memory.wasm";
// console.log(BindingsWasm);
// new WebAssembly.instantiate(BindingsWasm, );
// console.log(BindingsWasm);

const oldInstantiate = WebAssembly.instantiate;
WebAssembly.instantiate = async function (bytes, bindings) {
  for (let [key, value] of Object.entries(bindings.wbg)) {
    // bindings.wbg[key] = (...args) => {
    //   console.log("called", key);
    //   return value.apply(bindings, args);
    // };
  }
  console.log("instantiated", Object.keys(bindings.wbg));
  if (bytes === BindingsWasm) {
    const mod = new WebAssembly.Module(bytes);
    // console.log("returning");
    const instance = new WebAssembly.Instance(mod, bindings);
    console.log("returning instance");
    return instance;
  } else {
    return oldInstantiate(...arguments);
  }
  // console.log(bindings);

  // return new Promise((resolve) => resolve({}));
};

console.log("trying...");
// const memory = new WebAssembly.Memory({
//   initial: 10,
//   maximum: 100,
// });
// const importObject = {
//   my_namespace: { imported_func: (arg) => console.log(arg) },
// };
// const mod = new WebAssembly.Module(BindingsWasm);
// const wasm = new WebAssembly.Instance(mod, { js: { mem: memory } });
// const summands = new DataView(memory.buffer);

// for (let i = 0; i < 10; i++) {
//   summands.setUint32(i * 4, i, true); // WebAssembly is little endian
// }
// const sum = wasm.exports.accumulate(0, 10);
// console.log(sum);

// console.log(wasmInstance);
// WebAssembly.instantiate(BindingsWasm, {})
//   .then((result) => {
//     console.log("result", result);
//   })
//   .catch((error) => console.error("error: ", error));

globalThis.fetch = function (url) {
  // console.log(url);
  if (url.toString() === "http://example.com/bindings_wasm_bg.wasm") {
    // console.log("stubbing fetch");
    console.log("FETCH");
    return new Promise((resolve) => resolve(BindingsWasm));
  }
  console.error("fetch not implemented");
  throw "fetch not implemented";
};

// WebAssembly.instantiate = console.log;

// const dom = new JSDOM(`<!DOCTYPE html><p>Hello world</p>`);

// globalThis.window = dom.window.window;
// globalThis.document = dom.window.document;

const modules = {
  "main.js": `import foo from 'foo.js'; console.log(foo); {
    @test
    someProp(){
      console.log("prop");
    }
    
  `,
  "foo.js": "export default 42;",
};

const rollupResult = rollup({
  input: "main.js",
  logLevel: "info",
  onLog(level, message) {
    console.log(level, message);
  },
  plugins: [
    {
      name: "loader",
      resolveId(source) {
        console.log("resolveid");
        if (modules.hasOwnProperty(source)) {
          return source;
        }
      },
      load(id) {
        if (modules.hasOwnProperty(id)) {
          return modules[id];
        }
      },
    },
  ],
});

rollupResult
  .then((bundle) => {
    console.log("Hello 1");
    return bundle.generate({ format: "es" });
  })
  .then(({ output }) => console.log("result", output[0].code))
  .catch((error) => console.error("error: ", error, error.stack));

let result;
globalThis.getResult = function () {
  return result;
};

globalThis.doSomething = async function doSomething() {
  await new Promise((resolve) => resolve());
  console.log("returned");
  return "thing";
};

// console.log("done eval", rollupResult);