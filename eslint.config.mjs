import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    rules: {
      "ember/no-classic-classes": "error",
      "discourse/i18n-import-location": "error",
      "discourse/i18n-t": "error",
      "qunit/no-assert-equal-boolean": "error",
      "qunit/no-assert-equal": "error",
      "qunit/no-loose-assertions": "error",
      "qunit/no-negated-ok": "error",
      "qunit/no-ok-equality": "error",
    },
  },
  {
    ignores: [
      "app/assets/javascripts/ember-addons/",
      "lib/javascripts/locale/*",
      "lib/javascripts/messageformat.js",
      "lib/javascripts/messageformat-lookup.js",
      "plugins/**/lib/javascripts/locale",
      "public/",
      "vendor/",
      "app/assets/javascripts/discourse/tests/fixtures",
      "**/node_modules/",
      "spec/",
      "app/assets/javascripts/discourse/dist/",
      "tmp/",
    ],
  },
];
