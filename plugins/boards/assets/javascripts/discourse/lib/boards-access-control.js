import { AUTO_GROUPS } from "discourse/lib/constants";

export function buildDefaultBoardAcl(site, siteSettings) {
  const managerGroupIds = siteSettings.groupSettingArray(
    "boards_manage_board_allowed_groups"
  );
  const defaultAcl = [];

  managerGroupIds.forEach((groupId) => {
    const group = site.groupsById[groupId];
    if (group) {
      defaultAcl.push({
        type: "group",
        id: group.id,
        permission: "manage",
        display_name: group.full_name,
      });
    }
  });

  if (!managerGroupIds.includes(AUTO_GROUPS.logged_in_users.id)) {
    defaultAcl.push({
      type: "group",
      id: AUTO_GROUPS.logged_in_users.id,
      permission: "view",
      display_name: site.groupFullName(AUTO_GROUPS.logged_in_users.id),
    });
  }

  return defaultAcl;
}
