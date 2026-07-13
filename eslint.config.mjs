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
      "plugins/discourse-math/public",
      "public/",
      "vendor/",
      "**/node_modules/",
      "spec/",
      "frontend/discourse/dist/",
      "**/*.d.ts",
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
    languageOptions: {
      parserOptions: {
        babelOptions: {
          configFile: false,
        },
      },
    },
  },
];
