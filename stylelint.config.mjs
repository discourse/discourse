import noCoreVariables from "./stylelint-rules/no-core-variables.mjs";

export default {
  extends: ["@discourse/lint-configs/stylelint"],
  plugins: [noCoreVariables],
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
      },
    },
  ],
};
