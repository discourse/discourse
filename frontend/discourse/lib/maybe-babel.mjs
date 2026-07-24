import { and, code, id, include, not, or } from "@rolldown/pluginutils";
import { babel } from "@rollup/plugin-babel";

const babelRequiredImports = [
  // Templates
  "@ember/template-compiler",
  "@ember/template-compilation",
  "ember-cli-htmlbars",
  "ember-cli-htmlbars-inline-precompile",
  "htmlbars-inline-precompile",

  // Macros
  "@embroider/macros",
  "@glimmer/env",
  "@ember/debug",
  "@ember/application/deprecations",
];

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

const importsRegex = new RegExp(
  babelRequiredImports.map(escapeRegExp).join("|")
);

const decoratorRegex = /(?<![\w'"`])(?<!\*\s)(?<!\/\/[^\n]*)@\w+/;
//                      └────┬─────┘└───┬───┘└──────┬──────┘└┬─┘
//                           │          │           │         │
//                           │          │           │         └── the `@decorator`
//                           │          │           └── not on a `//` line comment
//                           │          └── not a JSDoc tag (`* @param`)
//                           └── not mid-identifier or inside a string

const nodeModulesPattern = /\/node_modules\//;

export default function maybeBabel(config) {
  const plugin = babel(config);

  // Extract existing regex filter from babel plugin
  const extensionRegex = plugin.transform.filter.id;

  plugin.transform.filter = [
    include(
      and(
        id(extensionRegex), // Is one of the babel-supported extensions
        or(
          code(importsRegex), // Imports one of our listed modules
          and(not(id(nodeModulesPattern)), code(decoratorRegex)) // Is local app code which uses a decorator
        )
      )
    ),
  ];
  return plugin;
}
