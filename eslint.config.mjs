import DiscourseRecommended from "@discourse/lint-configs/eslint";
import tsdoc from "eslint-plugin-tsdoc";

export default [
  ...DiscourseRecommended,
  {
    rules: {
      "ember/template-no-capital-arguments": "off",
      "ember/template-require-button-type": "off",
    },
  },
  // TEMPORARY: TSDoc syntax linting is scoped to the blocks tree while it is
  // being authored in TypeScript, to keep the new doc comments TSDoc-clean.
  // This whole block (and the eslint-plugin-tsdoc devDependency) should be
  // removed once tsdoc/syntax is enabled repo-wide via @discourse/lint-configs.
  {
    files: [
      "frontend/discourse/app/blocks/**/*.{ts,gts}",
      "frontend/discourse/app/lib/blocks/**/*.{ts,gts}",
      "frontend/discourse/app/static/dev-tools/block-debug/**/*.{ts,gts}",
      "frontend/discourse/app/services/blocks.ts",
      "frontend/discourse/app/initializers/freeze-block-registry.ts",
      "frontend/discourse/app/lib/registry/block-outlets.ts",
    ],
    plugins: { tsdoc },
    rules: { "tsdoc/syntax": "error" },
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
