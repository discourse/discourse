import DiscourseRecommended from "@discourse/lint-configs/eslint";
import noCrossGroupInternals from "./frontend/lint-rules/no-cross-group-internals.mjs";

export default [
  ...DiscourseRecommended,
  {
    files: ["**/*.{js,gjs,ts,gts}"],
    plugins: {
      "discourse-local": {
        rules: {
          "no-cross-group-internals": noCrossGroupInternals,
        },
      },
    },
    rules: {
      "discourse-local/no-cross-group-internals": "error",
    },
  },
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
