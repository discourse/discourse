import { helperContext } from "discourse/lib/helpers";
import type SiteSettingsService from "discourse/services/site-settings";

/**
 * Resolves the style a category should render with. Emoji-styled categories
 * fall back to the default square while emoji are disabled, keeping the saved
 * emoji for when they're re-enabled.
 *
 * @param styleType - the category's saved style type
 * @returns The style to render with.
 */
export default function categoryStyleType(styleType?: string | null) {
  if (
    styleType === "emoji" &&
    // TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys;
    // remove this cast once it does.
    !(
      helperContext().siteSettings as SiteSettingsService & {
        enable_emoji: boolean;
      }
    ).enable_emoji
  ) {
    return "square";
  }

  return styleType;
}
