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
    files: ["frontend/discourse/app/ui-kit/**/*.{js,gjs}"],
    // These files predate the rule. Remove each one once it is converted.
    ignores: [
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
          message: "Write ui-kit modules in TypeScript (.ts or .gts).",
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
