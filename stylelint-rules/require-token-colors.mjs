import stylelint from "stylelint";

const ruleName = "discourse/require-token-colors";

const messages = stylelint.utils.ruleMessages(ruleName, {
  rejectedLegacyVar: (varName) =>
    `Unexpected legacy color variable "${varName}". Use a design token (--dt-*) or sidebar component variable (--d-sidebar-*) instead.`,
  rejectedNonTokenVar: (varName) =>
    `Unexpected color variable "${varName}". Use a design token (--dt-*) or sidebar component variable (--d-sidebar-*) instead.`,
  rejectedHardCodedColor: (value) =>
    `Unexpected hard-coded color "${value}". Use a design token (--dt-*) or sidebar component variable (--d-sidebar-*) instead.`,
});

// Legacy Discourse color variable families (from color_definitions.scss)
const LEGACY_COLOR_PREFIXES = [
  "primary",
  "secondary",
  "tertiary",
  "quaternary",
  "header_background",
  "header_primary",
  "header-background",
  "header-primary",
  "highlight",
  "danger",
  "success",
  "love",
  "wiki",
];

// Matches legacy color variable names (the part after --)
// Covers: primary, primary-low, primary-50, primary-rgb, blend-*, *-or-*, etc.
const LEGACY_VAR_PATTERN = new RegExp(
  "^(" +
    LEGACY_COLOR_PREFIXES.join("|") +
    ")($|-)" +
    "|^blend-" +
    "|-or-" +
    "|^(google|facebook|twitter|instagram|github|discord|cas)($|-)" +
    "|^(d-selected|d-hover|inline-code-bg)($|-)" +
    "|^hljs-"
);

// Dedicated CSS properties where the value is exclusively a color
const COLOR_PROPERTIES = new Set([
  "color",
  "background-color",
  "border-color",
  "border-top-color",
  "border-right-color",
  "border-bottom-color",
  "border-left-color",
  "border-block-color",
  "border-block-start-color",
  "border-block-end-color",
  "border-inline-color",
  "border-inline-start-color",
  "border-inline-end-color",
  "outline-color",
  "text-decoration-color",
  "column-rule-color",
  "caret-color",
  "accent-color",
  "fill",
  "stroke",
  "scrollbar-color",
]);

// Keywords in custom property names that indicate color values
const COLOR_NAME_KEYWORDS = [
  "color",
  "background",
  "bg",
  "fade",
  "shadow",
  "border-color",
];

// CSS named colors (comprehensive list)
const NAMED_COLORS = new Set([
  "aliceblue",
  "antiquewhite",
  "aqua",
  "aquamarine",
  "azure",
  "beige",
  "bisque",
  "black",
  "blanchedalmond",
  "blue",
  "blueviolet",
  "brown",
  "burlywood",
  "cadetblue",
  "chartreuse",
  "chocolate",
  "coral",
  "cornflowerblue",
  "cornsilk",
  "crimson",
  "cyan",
  "darkblue",
  "darkcyan",
  "darkgoldenrod",
  "darkgray",
  "darkgreen",
  "darkgrey",
  "darkkhaki",
  "darkmagenta",
  "darkolivegreen",
  "darkorange",
  "darkorchid",
  "darkred",
  "darksalmon",
  "darkseagreen",
  "darkslateblue",
  "darkslategray",
  "darkslategrey",
  "darkturquoise",
  "darkviolet",
  "deeppink",
  "deepskyblue",
  "dimgray",
  "dimgrey",
  "dodgerblue",
  "firebrick",
  "floralwhite",
  "forestgreen",
  "fuchsia",
  "gainsboro",
  "ghostwhite",
  "gold",
  "goldenrod",
  "gray",
  "green",
  "greenyellow",
  "grey",
  "honeydew",
  "hotpink",
  "indianred",
  "indigo",
  "ivory",
  "khaki",
  "lavender",
  "lavenderblush",
  "lawngreen",
  "lemonchiffon",
  "lightblue",
  "lightcoral",
  "lightcyan",
  "lightgoldenrodyellow",
  "lightgray",
  "lightgreen",
  "lightgrey",
  "lightpink",
  "lightsalmon",
  "lightseagreen",
  "lightskyblue",
  "lightslategray",
  "lightslategrey",
  "lightsteelblue",
  "lightyellow",
  "lime",
  "limegreen",
  "linen",
  "magenta",
  "maroon",
  "mediumaquamarine",
  "mediumblue",
  "mediumorchid",
  "mediumpurple",
  "mediumseagreen",
  "mediumslateblue",
  "mediumspringgreen",
  "mediumturquoise",
  "mediumvioletred",
  "midnightblue",
  "mintcream",
  "mistyrose",
  "moccasin",
  "navajowhite",
  "navy",
  "oldlace",
  "olive",
  "olivedrab",
  "orange",
  "orangered",
  "orchid",
  "palegoldenrod",
  "palegreen",
  "paleturquoise",
  "palevioletred",
  "papayawhip",
  "peachpuff",
  "peru",
  "pink",
  "plum",
  "powderblue",
  "purple",
  "rebeccapurple",
  "red",
  "rosybrown",
  "royalblue",
  "saddlebrown",
  "salmon",
  "sandybrown",
  "seagreen",
  "seashell",
  "sienna",
  "silver",
  "skyblue",
  "slateblue",
  "slategray",
  "slategrey",
  "snow",
  "springgreen",
  "steelblue",
  "tan",
  "teal",
  "thistle",
  "tomato",
  "turquoise",
  "violet",
  "wheat",
  "white",
  "whitesmoke",
  "yellow",
  "yellowgreen",
]);

// Values that are acceptable even though they look like colors
const ALLOWED_COLOR_KEYWORDS = new Set([
  "transparent",
  "currentcolor",
  "inherit",
  "initial",
  "unset",
  "revert",
  "none",
]);

const HEX_COLOR_PATTERN = /#(?:[0-9a-f]{3,4}){1,2}\b/i;
const COLOR_FUNCTION_PATTERN =
  /\b(?:rgb|rgba|hsl|hsla|hwb|lab|lch|oklch|oklab|color)\s*\(/i;
const VAR_EXTRACT_PATTERN = /var\(\s*--([\w-]+)/g;

function isAllowedVar(varName) {
  return varName.startsWith("dt-") || varName.startsWith("d-sidebar-");
}

function isLegacyColorVar(varName) {
  return LEGACY_VAR_PATTERN.test(varName);
}

function isColorProperty(prop) {
  return COLOR_PROPERTIES.has(prop);
}

function isColorCustomProperty(prop) {
  if (!prop.startsWith("--")) {
    return false;
  }
  const name = prop.slice(2).toLowerCase();
  return COLOR_NAME_KEYWORDS.some((keyword) => name.includes(keyword));
}

function hasTokenInRelativeColor(value) {
  return /\b(?:rgb|hsl|hwb|lab|lch|oklch|oklab|color)\s*\(\s*from\s+var\(\s*--(?:dt-|d-sidebar-)/.test(
    value
  );
}

const ruleFunction = (primaryOption) => {
  return (root, result) => {
    if (!primaryOption) {
      return;
    }

    root.walkDecls((decl) => {
      const { prop, value } = decl;

      const isColorProp = isColorProperty(prop);
      const isColorCustomProp = isColorCustomProperty(prop);
      const shouldCheckAllowlist = isColorProp || isColorCustomProp;

      // Tier 1 + Tier 2: Check var() references
      let match;
      VAR_EXTRACT_PATTERN.lastIndex = 0;
      while ((match = VAR_EXTRACT_PATTERN.exec(value)) !== null) {
        const varName = match[1];

        if (isAllowedVar(varName)) {
          continue;
        }

        // Tier 2: Blocklist — flag legacy vars on ANY property
        if (isLegacyColorVar(varName)) {
          stylelint.utils.report({
            message: messages.rejectedLegacyVar(`--${varName}`),
            node: decl,
            result,
            ruleName,
            word: `var(--${varName})`,
          });
          continue;
        }

        // Tier 1: Allowlist — flag non-token vars on color properties
        if (shouldCheckAllowlist) {
          stylelint.utils.report({
            message: messages.rejectedNonTokenVar(`--${varName}`),
            node: decl,
            result,
            ruleName,
            word: `var(--${varName})`,
          });
        }
      }

      // Tier 3: Hard-coded colors on color properties and color custom properties
      if (shouldCheckAllowlist) {
        // Check for hex colors
        const hexMatch = value.match(HEX_COLOR_PATTERN);
        if (hexMatch) {
          stylelint.utils.report({
            message: messages.rejectedHardCodedColor(hexMatch[0]),
            node: decl,
            result,
            ruleName,
            word: hexMatch[0],
          });
        }

        // Check for color functions (rgb, hsl, etc.)
        // Allow relative color syntax that references tokens
        if (
          COLOR_FUNCTION_PATTERN.test(value) &&
          !hasTokenInRelativeColor(value)
        ) {
          stylelint.utils.report({
            message: messages.rejectedHardCodedColor(
              value.match(COLOR_FUNCTION_PATTERN)[0].trim()
            ),
            node: decl,
            result,
            ruleName,
          });
        }

        // Check for named CSS colors
        // Strip var() references first to avoid matching words inside them
        const valueWithoutVars = value.replace(/var\([^)]*\)/g, "");
        const words = valueWithoutVars.split(/[\s,/()]+/);
        for (const word of words) {
          const lower = word.toLowerCase();
          if (NAMED_COLORS.has(lower) && !ALLOWED_COLOR_KEYWORDS.has(lower)) {
            stylelint.utils.report({
              message: messages.rejectedHardCodedColor(word),
              node: decl,
              result,
              ruleName,
              word,
            });
          }
        }
      }
    });
  };
};

ruleFunction.ruleName = ruleName;
ruleFunction.messages = messages;
ruleFunction.meta = { fixable: false };

export default stylelint.createPlugin(ruleName, ruleFunction);
