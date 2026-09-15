import { AUTO_GROUPS } from "discourse/lib/constants";
import { i18n } from "discourse-i18n";

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

export function boardPermissionOptions(options) {
  const viewOption = options.find((option) => option.id === "view");
  viewOption.description = i18n(
    "boards.manage.board_access_permission_viewer_description"
  );

  const editOption = options.find((option) => option.id === "edit");
  editOption.description = i18n(
    "boards.manage.board_access_permission_editor_description"
  );

  options.push({
    id: "manage",
    level: 3,
    name: i18n("boards.manage.board_access_permission_manager"),
    description: i18n(
      "boards.manage.board_access_permission_manager_description"
    ),
  });

  return options;
}
