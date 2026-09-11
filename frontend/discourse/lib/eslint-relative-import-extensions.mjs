import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";

const SOURCE_EXTENSIONS = [".ts", ".js", ".gts", ".gjs"];
const KNOWN_EXTENSIONS = [
  ...SOURCE_EXTENSIONS,
  ".mjs",
  ".cjs",
  ".mts",
  ".cts",
  ".json",
  ".css",
  ".scss",
  ".hbs",
  ".wasm",
];

function hasExtension(specifier) {
  return KNOWN_EXTENSIONS.some((ext) => specifier.endsWith(ext));
}

function resolveExtension(importer, specifier) {
  const target = resolve(dirname(importer), specifier);
  for (const ext of SOURCE_EXTENSIONS) {
    if (existsSync(target + ext)) {
      return specifier + ext;
    }
  }
  for (const ext of SOURCE_EXTENSIONS) {
    if (existsSync(resolve(target, `index${ext}`))) {
      return `${specifier.replace(/\/$/, "")}/index${ext}`;
    }
  }
  return null;
}

export default {
  meta: {
    type: "problem",
    fixable: "code",
    messages: {
      missing:
        "Relative import '{{specifier}}' must include the file extension.",
    },
    schema: [],
  },
  create(context) {
    function check(node) {
      if (!node || node.type !== "Literal" || typeof node.value !== "string") {
        return;
      }
      const specifier = node.value;
      if (
        !specifier.startsWith(".") ||
        specifier.includes("?") ||
        hasExtension(specifier)
      ) {
        return;
      }
      const fixed = resolveExtension(context.filename, specifier);
      context.report({
        node,
        messageId: "missing",
        data: { specifier },
        fix: fixed ? (fixer) => fixer.replaceText(node, `"${fixed}"`) : null,
      });
    }

    return {
      ImportDeclaration: (node) => check(node.source),
      ExportNamedDeclaration: (node) => check(node.source),
      ExportAllDeclaration: (node) => check(node.source),
      ImportExpression: (node) => check(node.source),
      CallExpression: (node) => {
        if (
          node.callee.type === "Identifier" &&
          node.callee.name === "importSync"
        ) {
          check(node.arguments[0]);
        }
      },
    };
  },
};
