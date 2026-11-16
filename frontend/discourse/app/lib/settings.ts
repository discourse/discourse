import { helperContext } from "discourse/lib/helpers";
import type SiteSettingsService from "discourse/services/site-settings";

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the settings read here. Remove it once the service types its settings.
 */
interface NameSettings {
  enable_names: boolean;
  prioritize_username_in_ux: boolean;
  display_name_on_posts: boolean;
  external_emoji_url: string;
}

/**
 * Whether the UI should show a person's name instead of their username.
 *
 * @param name - The person's name.
 * @returns A truthy value when names are enabled, not overridden by usernames, and the
 *   name is not blank.
 */
export function prioritizeNameInUx(name?: string | null) {
  const siteSettings = helperContext().siteSettings as SiteSettingsService &
    NameSettings;

  return (
    siteSettings.enable_names &&
    !siteSettings.prioritize_username_in_ux &&
    name &&
    name.trim().length > 0
  );
}

/**
 * Picks what to show on posts: the name, when the site shows names there, or else the
 * username.
 *
 * @param name - The person's name.
 * @param username - The person's username.
 * @returns The name, or the username when the name is missing or names are hidden.
 */
export function prioritizeNameFallback(
  name: string | null | undefined,
  username: string | null | undefined
) {
  const siteSettings = helperContext().siteSettings as SiteSettingsService &
    NameSettings;
  if (
    siteSettings.enable_names &&
    siteSettings.display_name_on_posts &&
    !siteSettings.prioritize_username_in_ux
  ) {
    return name || username;
  } else {
    return username;
  }
}

/**
 * The base path of the emoji images.
 *
 * @returns The external emoji URL when one is set, or the local emoji path.
 */
export function emojiBasePath() {
  const siteSettings = helperContext().siteSettings as SiteSettingsService &
    NameSettings;

  return siteSettings.external_emoji_url === ""
    ? "/images/emoji"
    : siteSettings.external_emoji_url;
}
