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
    files: [
      "frontend/discourse/float-kit/**/*.{js,gjs,ts,gts}",
      "frontend/discourse/app/ui-kit/modifiers/**/*.{js,gjs,ts,gts}",
      "frontend/discourse/app/ui-kit/d-tabs/**/*.{js,gjs,ts,gts}",
    ],
    rules: {
      "no-restricted-globals": [
        "error",
        {
          name: "document",
          message:
            "Resolve the document from the element's ownerDocument instead.",
        },
        {
          name: "window",
          message:
            "Resolve the window from the element's ownerDocument.defaultView instead.",
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
