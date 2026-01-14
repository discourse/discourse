import { minify as terserMinify } from "terser";

export default function discourseTerser({ opts }) {
  return {
    name: "discourse-terser",
    async renderChunk(code, chunk, outputOptions) {
      if (!opts.minify) {
        return;
      }

      // Based on https://github.com/ember-cli/ember-cli-terser/blob/28df3d90a5/index.js#L12-L26
      const defaultOptions = {
        sourceMap:
          outputOptions.sourcemap === true ||
          typeof outputOptions.sourcemap === "string",
        compress: {
          negate_iife: false,
          sequences: 30,
          drop_debugger: false,
        },
        output: {
          semicolons: false,
        },
      };

      defaultOptions.module = true;

      return await terserMinify(code, defaultOptions);
    },
  };
}
