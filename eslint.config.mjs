import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    rules: {
      "qunit/no-assert-equal": "error",
      "qunit/no-loose-assertions": "error",
      "ember/no-classic-components": "error",
    },
  },
  {
    ignores: [
      "js/ember-addons/",
      "lib/javascripts/locale/*",
      "lib/javascripts/messageformat.js",
      "lib/javascripts/messageformat-lookup.js",
      "plugins/**/lib/javascripts/locale",
      "plugins/discourse-math/public",
      "public/",
      "vendor/",
      "js/discourse/tests/fixtures",
      "**/node_modules/",
      "spec/",
      "js/discourse/dist/",
      "tmp/",
    ],
  },
  {
    files: ["themes/**/*.{js,gjs}"],
    languageOptions: {
      globals: {
        settings: "readonly",
        themePrefix: "readonly",
      },
    },
  },
];
