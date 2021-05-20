import { helperContext } from "discourse-common/lib/helpers";

export function resolveShareUrl(url, user) {
  const badgesEnabled = helperContext().siteSettings.enable_badges;
  const userSuffix = user && badgesEnabled ? `?u=${user.username_lower}` : "";

  return url + userSuffix;
}
