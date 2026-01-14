/* eslint-disable no-bitwise */

// Simple, fast hashing function (djb2)
const hashString = (str) => {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) + hash + str.charCodeAt(i);
    hash = hash >>> 0; // Convert to unsigned 32-bit integer
  }
  return hash.toString(16).slice(0, 8);
};

/**
 * Adds a hash of the current file as a prefix to variables
 * introduced by the light-dark polyfill. This ensures that
 * usage across different files cannot conflict.
 */

const namespacesToPrefix = ["--csstools-light-dark-toggle-"];

export default function postcssVariablePrefixer() {
  let hash;

  return {
    postcssPlugin: "postcss-var-prefixer",

    Once(root) {
      hash = hashString(root.source.input.css);
    },

    Declaration(declaration) {
      const prop = declaration.prop;

      for (const prefix of namespacesToPrefix) {
        if (declaration.prop.startsWith(prefix)) {
          declaration.prop = `--${hash}-${prop.slice(2)}`;
        }

        if (declaration.value.includes(prefix)) {
          declaration.value = declaration.value.replaceAll(
            prefix,
            `--${hash}-${prefix.slice(2)}`
          );
        }
      }
    },
  };
}

postcssVariablePrefixer.postcss = true;
