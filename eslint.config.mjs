import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    rules: {
      "ember/no-classic-classes": "error",
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
