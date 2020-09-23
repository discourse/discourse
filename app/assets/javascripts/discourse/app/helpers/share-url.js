import { helperContext } from "discourse-common/lib/helpers";
import User from "discourse/models/user";

export function resolveShareUrl(url) {
  const siteSettings = helperContext().siteSettings;
  const user = User.current();
  const badgesEnabled = siteSettings.enable_badges;
  const userSuffix = user && badgesEnabled ? `?u=${user.username_lower}` : "";

  return url + userSuffix;
}
