import noCoreColorVariables from "./stylelint-color-rules.mjs";

export default {
  extends: ["@discourse/lint-configs/stylelint"],
  plugins: [noCoreColorVariables],
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
