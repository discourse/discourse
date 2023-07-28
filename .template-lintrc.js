module.exports = {
  plugins: ["ember-template-lint-plugin-discourse"],
  extends: "discourse:recommended",

  rules: {
    "no-action-modifiers": true,
    "no-args-paths": true,
    "no-array-prototype-extensions": false,
    "no-attrs-in-components": true,
    "no-capital-arguments": false, // TODO: we extensively use `args` argument name
    "no-curly-component-invocation": {
      allow: [
        // These are helpers, not components
        "directory-item-header-title",
        "directory-item-user-field-value",
        "directory-item-value",
        "directory-table-header-title",
        "loading-spinner",
        "directory-item-label",
      ],
    },
    "no-implicit-this": {
      allow: ["loading-spinner"],
    },
    "no-obscure-array-access": false,
    "require-mandatory-role-attributes": false,
    "require-media-caption": false,
    // Begin prettier compatibility
    "eol-last": false,
    "self-closing-void-elements": false,
    "block-indentation": false,
    quotes: false,
    // End prettier compatibility
  },
};
