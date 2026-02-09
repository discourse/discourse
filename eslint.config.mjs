import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    rules: {},
    // custom overrides go here
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
