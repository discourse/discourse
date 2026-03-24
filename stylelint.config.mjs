import noCoreVariables from "./stylelint-rules/no-core-variables.mjs";
import requireTokenColors from "./stylelint-rules/require-token-colors.mjs";

export default {
  extends: ["@discourse/lint-configs/stylelint"],
  plugins: [requireTokenColors, noCoreVariables],
  rules: {
    "media-feature-range-notation": "context",
  },
  overrides: [
    {
      files: ["**/sidebar.scss", "**/sidebar-*.scss"],
      rules: {
        "discourse/no-core-color-variables": true,
      },
    },
  ],
};
