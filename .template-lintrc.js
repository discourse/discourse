module.exports = {
  plugins: ["ember-template-lint-plugin-discourse"],
  extends: "discourse:recommended",

  rules: {
    "no-action-modifiers": true,
    "no-args-paths": true,
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
        "mobile-directory-item-label",
      ],
    },
    "no-implicit-this": {
      allow: ["loading-spinner"],
    },
    // Begin prettier compatibility
    "eol-last": false,
    "self-closing-void-elements": false,
    "block-indentation": false,
    quotes: false,
    // End prettier compatibility
  },
};
