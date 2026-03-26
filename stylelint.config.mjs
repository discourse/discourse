import noCoreVariables from "./stylelint-rules/no-core-variables.mjs";
import requireDesignTokens from "./stylelint-rules/require-design-tokens.mjs";

export default {
  extends: ["@discourse/lint-configs/stylelint"],
  plugins: [noCoreVariables, requireDesignTokens],
  rules: {
    "media-feature-range-notation": "context",
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
  ],
};
