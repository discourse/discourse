import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    rules: {
      "ember/template-no-capital-arguments": "off",
      "ember/template-require-button-type": "off",
    },
  },
  {
    ignores: [
      "plugins/**/lib/javascripts/locale",
      "plugins/blog/vendor/",
      "plugins/discourse-math/public",
      "public/",
      "vendor/",
      "**/node_modules/",
      "spec/",
      "frontend/discourse/dist/",
      "**/*.d.ts",
      "**/*.d.*.ts",
      "frontend/discourse-types/external-types",
      "frontend/discourse-types/dts-generator.{js,ts}",
      "tmp/",
    ],
  },
  {
    files: ["themes/**/*.{js,gjs,ts,gts}"],
    languageOptions: {
      globals: {
        settings: "readonly",
        themePrefix: "readonly",
      },
    },
  },
  {
    files: [
      "frontend/discourse/admin/models/**/*.{js,gjs}",
      "frontend/discourse/app/blocks/**/*.{js,gjs}",
      "frontend/discourse/app/lib/-internals/**/*.{js,gjs}",
      "frontend/discourse/app/lib/blocks/**/*.{js,gjs}",
      "frontend/discourse/app/models/**/*.{js,gjs}",
      "frontend/discourse/app/static/dev-tools/block-debug/**/*.{js,gjs}",
      "frontend/discourse/app/ui-kit/**/*.{js,gjs}",
      "frontend/discourse/float-kit/**/*.{js,gjs}",
      "frontend/discourse/pretty-text/**/*.{js,gjs}",
      "frontend/discourse/truth-helpers/**/*.{js,gjs}",
    ],
    ignores: [
      // Module loaders that `app.js` imports.
      "frontend/discourse/float-kit/compat-modules.js",
      "frontend/discourse/truth-helpers/compat-modules.js",

      // These files predate the rule. Remove each one once it is converted.
      "frontend/discourse/app/ui-kit/d-access-control-field.gjs",
      "frontend/discourse/app/ui-kit/d-access-control-permission-menu.gjs",
      "frontend/discourse/app/ui-kit/d-access-control.gjs",
      "frontend/discourse/app/ui-kit/d-access-control/-internals/grantee-chooser.gjs",
      "frontend/discourse/app/ui-kit/d-autocomplete-results.gjs",
      "frontend/discourse/app/ui-kit/d-calendar-date-time-input.gjs",
      "frontend/discourse/app/ui-kit/d-date-input.gjs",
      "frontend/discourse/app/ui-kit/d-date-picker.gjs",
      "frontend/discourse/app/ui-kit/d-editor.gjs",
      "frontend/discourse/app/ui-kit/d-future-date-input.gjs",
      "frontend/discourse/app/ui-kit/d-icon-grid-picker/content.gjs",
      "frontend/discourse/app/ui-kit/d-icon-grid-picker/index.gjs",
      "frontend/discourse/app/ui-kit/d-multi-select.gjs",
      "frontend/discourse/app/ui-kit/d-password-field.js",
      "frontend/discourse/app/ui-kit/d-pick-files-button.gjs",
      "frontend/discourse/app/ui-kit/d-popup-input-tip.gjs",
      "frontend/discourse/app/ui-kit/d-radio-button.js",
      "frontend/discourse/app/ui-kit/d-relative-time-picker.gjs",
      "frontend/discourse/app/ui-kit/d-save-controls.gjs",
      "frontend/discourse/app/ui-kit/d-text-field.js",
      "frontend/discourse/app/ui-kit/d-textarea.gjs",
      "frontend/discourse/app/ui-kit/d-time-input.gjs",
      "frontend/discourse/app/ui-kit/d-time-shortcut-picker.gjs",
      "frontend/discourse/app/ui-kit/d-user-info.gjs",
      "frontend/discourse/app/ui-kit/modifiers/d-autocomplete.js",
      "frontend/discourse/app/ui-kit/modifiers/d-draggable.js",
    ],
    rules: {
      "no-restricted-syntax": [
        "error",
        {
          selector: "Program",
          message: "Write this module in TypeScript (.ts or .gts).",
        },
      ],
    },
  },
  {
    languageOptions: {
      parserOptions: {
        babelOptions: {
          configFile: false,
        },
      },
    },
  },
];
