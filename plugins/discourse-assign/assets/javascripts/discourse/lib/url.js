import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";

export function assignedToUserPath(assignedToUser) {
  const siteSettings = getOwnerWithFallback(this).lookup(
    "service:site-settings"
  );

  return getURL(
    siteSettings.assigns_user_url_path.replace(
      "{username}",
      assignedToUser.username
    )
  );
}

export function assignedToGroupPath(assignedToGroup) {
  return getURL(`/g/${assignedToGroup.name}/assigned/everyone`);
}
