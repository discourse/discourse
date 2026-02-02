import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    rules: {
      "qunit/no-assert-equal": "error",
      "discourse/moved-packages-import-paths": "error",
      "discourse/no-route-template": "error",
      "ember/no-classic-components": "error",
      "ember/no-side-effects": "error",
      "ember/require-tagless-components": "error",
      "qunit/no-loose-assertions": "error",
    },
  },
  {
    ignores: [
      "plugins/**/lib/javascripts/locale",
      "plugins/discourse-math/public",
      "public/",
      "vendor/",
      "frontend/discourse/tests/fixtures",
      "**/node_modules/",
      "spec/",
      "frontend/discourse/dist/",
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
