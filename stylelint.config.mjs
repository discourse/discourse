import requireTokenColors from "./stylelint-rules/require-token-colors.mjs";

export default {
  extends: ["@discourse/lint-configs/stylelint"],
  plugins: [requireTokenColors],
  rules: {
    "media-feature-range-notation": "context",
  },
  overrides: [
    {
      files: ["**/sidebar*.scss"],
      rules: {
        "discourse/require-token-colors": true,
      },
    },
  ],
};
