import { ajax } from "discourse/lib/ajax";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";

const ACCESS_CONTROL_GRANTEE_SEARCH_URL = "/access-control/grantees/search";

export function granteeValue(type, id) {
  return `${type}:${id}`;
}

export function groupGranteeResult(group) {
  return {
    value: granteeValue("group", group.id),
    id: group.name,
    aclId: group.id,
    aclType: "group",
    name: group.name,
    full_name: group.full_name,
    display_name: group.display_name,
    automatic: group.automatic,
    isGroup: true,
  };
}

function userGranteeResult(user) {
  const sortName = user.name || user.display_name || user.username;

  return {
    value: granteeValue("user", user.id),
    id: user.username,
    aclId: user.id,
    aclType: "user",
    name: user.name,
    sort_name: sortName,
    username: user.username,
    showUserStatus: false,
    avatar_template: user.avatar_template,
    isUser: true,
  };
}

/**
 * excludedGrantees: an array of grantee values (in format type:id) that should be excluded from the search results,
 * since they have already been selected. These are passed from DAccessControl.
 *
 * onlyShowGroupFullName: for DAccessControl, it's ugly/unnecessary to show the group short_name_with_underscores, we only
 * want to show the group full name.
 *
 * prioritizeUserNameOrdering: for DAccessControl, we want to respect the prioritize_username_in_ux site setting and
 * show the name before the username in the search results depending on the setting.
 */
@selectKitOptions({
  excludedGrantees: undefined,
  onlyShowGroupFullName: true,
  prioritizeUserNameOrdering: true,
})
export default class DAccessControlGranteeChooser extends EmailGroupUserChooser {
  valueProperty = "value";

  async search(filter = "") {
    if (!filter) {
      return Promise.resolve(
        this.selectKit.options.customSearchOptions?.defaultSearchResults || []
      );
    }

    try {
      const results = await ajax(ACCESS_CONTROL_GRANTEE_SEARCH_URL, {
        data: {
          term: filter,
          acl_target: this.selectKit.options.aclTarget,
        },
      });
      const results_2 = this.normalizeGranteeResults(results);
      return this.excludeSelectedGrantees(results_2);
    } catch {
      return [];
    }
  }

  normalizeGranteeResults(results) {
    if (!results) {
      return [];
    }

    return [
      ...(results.groups || []).map(groupGranteeResult),
      ...(results.users || []).map(userGranteeResult),
    ];
  }

  excludeSelectedGrantees(results) {
    const excludedGrantees = this.selectKit.options.excludedGrantees || [];

    if (!excludedGrantees.length) {
      return results;
    }

    return results.filter((result) => !excludedGrantees.includes(result.value));
  }
}
