import stylelint from "stylelint";

const ruleName = "discourse/require-design-tokens";

// Properties that must use --token-* variables instead of hardcoded values.
// Each entry maps a CSS property to the token prefix(es) that should be used.
const enforcedProperties = {
  // Colors — must use token vars, not raw colors
  color: "--token-text-* or --token-icon-*",
  "background-color": "--token-surface-* or --token-background-*",
  "border-color": "--token-border-*",

  // Font weight — must use --token-font-weight-*
  "font-weight": "--token-font-weight-*",

  // Border radius — must use --token-radius-*
  "border-radius": "--token-radius-*",
};

// Values that are always allowed (inherit, initial, transparent, currentColor, etc.)
const allowedGlobals = new Set([
  "inherit",
  "initial",
  "unset",
  "revert",
  "currentcolor",
  "transparent",
  "none",
  "0",
]);

// font-weight keywords that should use tokens instead
const fontWeightKeywords = new Set([
  "bold",
  "bolder",
  "lighter",
  "normal",
  "100",
  "200",
  "300",
  "400",
  "500",
  "600",
  "650",
  "700",
  "800",
  "900",
]);

function isTokenVar(value) {
  return /var\(\s*--token-/.test(value);
}

function containsRawColor(value) {
  // hex colors
  if (/#[0-9a-fA-F]{3,8}\b/.test(value)) {
    return true;
  }
  // rgb/rgba/hsl/hsla/oklch/lab/lch functions
  if (/\b(rgb|rgba|hsl|hsla|oklch|lab|lch|hwb|oklab)\s*\(/.test(value)) {
    return true;
  }
  // named colors (common ones — not exhaustive but covers the usual suspects)
  const namedColors =
    /\b(red|blue|green|yellow|orange|purple|pink|white|black|grey|gray|cyan|magenta|teal|navy|maroon|lime|olive|aqua|fuchsia|silver|indigo|violet|coral|salmon|tomato|gold|khaki|plum|orchid|sienna|tan|wheat|beige|ivory|linen|crimson|firebrick|darkred|darkblue|darkgreen|brown)\b/i;
  if (namedColors.test(value)) {
    return true;
  }
  return false;
}

export default stylelint.createPlugin(ruleName, (primaryOption) => {
  return (root, result) => {
    if (!primaryOption) {
      return;
    }

    root.walkDecls((decl) => {
      const prop = decl.prop.toLowerCase();
      const value = decl.value.trim().toLowerCase();

      // Skip custom property definitions (--token-* declarations themselves)
      if (prop.startsWith("--")) {
        return;
      }

      // Skip if already using a token variable
      if (isTokenVar(decl.value)) {
        return;
      }

      // Skip globally allowed values
      if (allowedGlobals.has(value)) {
        return;
      }

      const tokenSuggestion = enforcedProperties[prop];

      if (!tokenSuggestion) {
        return;
      }

      // Font weight check
      if (prop === "font-weight") {
        if (fontWeightKeywords.has(value)) {
          stylelint.utils.report({
            message: `Avoid hardcoded "${decl.value}" for ${prop}. Use a design token: ${tokenSuggestion}`,
            node: decl,
            result,
            ruleName,
            word: decl.value,
          });
        }
        return;
      }

      // Border radius check — flag raw length values, allow var()/calc() expressions
      if (prop === "border-radius") {
        const hasVar = /var\(/.test(decl.value);
        if (!hasVar && value !== "0") {
          stylelint.utils.report({
            message: `Avoid hardcoded "${decl.value}" for ${prop}. Use a design token: ${tokenSuggestion}`,
            node: decl,
            result,
            ruleName,
            word: decl.value,
          });
        }
        return;
      }

      // Color properties — flag raw colors
      if (containsRawColor(value)) {
        stylelint.utils.report({
          message: `Avoid hardcoded colors for ${prop}. Use a design token: ${tokenSuggestion}`,
          node: decl,
          result,
          ruleName,
          word: decl.value,
        });
      }
    });
  };
});
