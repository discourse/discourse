import { helperContext } from "discourse/lib/helpers";

export function resolveShareUrl(url, user) {
  const siteSettings = helperContext().siteSettings;
  const badgesEnabled = siteSettings.enable_badges;
  const allowUsername = siteSettings.allow_username_in_share_links;
  const userSuffix =
    user && badgesEnabled && allowUsername ? `?u=${user.username_lower}` : "";

  return url + userSuffix;
}
