import DiscourseRecommended from "@discourse/lint-configs/eslint";
import requireTsCheck from "./eslint-rules/require-ts-check.mjs";

const localPlugin = {
  rules: {
    "require-ts-check": requireTsCheck,
  },
};

export default [
  ...DiscourseRecommended,
  {
    rules: {},
    // custom overrides go here
  },
  {
    files: ["frontend/discourse/app/ui-kit/**/*.{js,gjs}"],
    plugins: { local: localPlugin },
    rules: {
      "local/require-ts-check": "error",
    },
  },
  {
    ignores: [
      "plugins/**/lib/javascripts/locale",
      "plugins/discourse-math/public",
      "public/",
      "vendor/",
      "**/node_modules/",
      "spec/",
      "frontend/discourse/dist/",
      "frontend/discourse-types/dts-generator.js",
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
