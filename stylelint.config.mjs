import noCoreVariables from "./stylelint-rules/no-core-variables.mjs";
import requireDesignTokens from "./stylelint-rules/require-design-tokens.mjs";
import ucClassesInWhere from "./stylelint-rules/uc-classes-in-where.mjs";

export default {
  extends: ["@discourse/lint-configs/stylelint"],
  plugins: [noCoreVariables, requireDesignTokens, ucClassesInWhere],
  rules: {
    "media-feature-range-notation": "context",
    "discourse/uc-classes-in-where": true,
  },
  overrides: [
    {
      files: [
        "**/sidebar.scss",
        "**/sidebar-*.scss",
        "**/*-sidebar.scss",
        "**/*-sidebar-*.scss",
      ],
      rules: {
        "discourse/no-core-color-variables": true,
        "discourse/require-design-tokens": true,
      },
    },
    {
      files: ["themes/horizon/scss/**"],
      rules: {
        "discourse/no-core-color-variables": null,
        "discourse/require-design-tokens": null,
      },
    },
  ],
};
