export default {
  extends: ["stylelint-config-standard-scss"],
  rules: {
    // Rules from @discourse/lint-configs/stylelint
    "color-no-invalid-hex": true,
    "unit-no-unknown": true,
    "rule-empty-line-before": [
      "always",
      { except: ["after-single-line-comment", "first-nested"] },
    ],
    "selector-class-pattern": null,
    "custom-property-pattern": null,
    "declaration-empty-line-before": "never",
    "alpha-value-notation": null,
    "color-function-notation": null,
    "shorthand-property-no-redundant-values": null,
    "declaration-block-no-redundant-longhand-properties": null,
    "no-descending-specificity": null,
    "keyframes-name-pattern": null,
    "scss/dollar-variable-pattern": null,
    "number-max-precision": null,
    "scss/at-extend-no-missing-placeholder": null,
    "scss/load-no-partial-leading-underscore": null,
    "scss/operator-no-newline-after": null,
    "selector-id-pattern": null,
    "no-invalid-position-at-import-rule": null,
    "scss/at-function-pattern": null,
    "scss/comment-no-empty": null,
    "scss/at-mixin-pattern": null,
    "declaration-property-value-keyword-no-deprecated": [
      true,
      { ignoreKeywords: ["break-word"] },
    ],
    "value-keyword-case": [
      "lower",
      {
        ignoreProperties: ["/^\\$/", "font", "font-family"],
      },
    ],

    // Replaces discourse/no-breakpoint-mixin custom plugin
    // Flags any @include breakpoint(...) usage
    "scss/at-mixin-disallowed-list": ["breakpoint"],

    // Discourse-specific override
    "media-feature-range-notation": "context",
  },
};
