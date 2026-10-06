import { helperContext } from "discourse/lib/helpers";

/**
 * Resolves the style a category should render with. Emoji-styled categories
 * fall back to the default square while emoji are disabled, keeping the saved
 * emoji for when they're re-enabled.
 *
 * @param {string} [styleType] the category's saved style type
 * @returns {string|undefined}
 */
export default function categoryStyleType(styleType) {
  if (styleType === "emoji" && !helperContext().siteSettings.enable_emoji) {
    return "square";
  }

  return styleType;
}
