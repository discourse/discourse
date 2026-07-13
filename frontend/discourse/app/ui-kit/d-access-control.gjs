import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { AUTO_GROUPS } from "discourse/lib/constants";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ACCESS_CONTROL_GRANTEE_SEARCH_URL = "/access-control/grantees/search";
const EDIT_PERMISSION = "edit";
const READ_ONLY_PERMISSION = "view";
const READ_ONLY_DEFAULT_AUTO_GROUPS = [
  AUTO_GROUPS.anonymous_users.id,
  AUTO_GROUPS.everyone.id,
  AUTO_GROUPS.trust_level_0.id,
];
const ROW_TYPE_SORT_ORDER = {
  group: 0,
  user: 1,
};
const REMOVE_ACTION = {
  id: "remove",
  name: i18n("access_control.manage.access_permission_remove"),
  description: i18n(
    "access_control.manage.access_permission_remove_description"
  ),
};

function defaultPermissions() {
  return [
    {
      id: READ_ONLY_PERMISSION,
      level: 1,
      name: i18n("access_control.manage.access_permission_viewer"),
      description: i18n(
        "access_control.manage.access_permission_viewer_description"
      ),
    },
    {
      id: EDIT_PERMISSION,
      level: 2,
      name: i18n("access_control.manage.access_permission_editor"),
      description: i18n(
        "access_control.manage.access_permission_editor_description"
      ),
    },
  ];
}

function granteeValue(type, id) {
  return `${type}:${id}`;
}

function rowTypeSortOrder(type) {
  return ROW_TYPE_SORT_ORDER[type] ?? 2;
}

function groupGranteeResult(group) {
  return {
    value: granteeValue("group", group.id),
    id: group.name,
    aclId: group.id,
    aclType: "group",
    name: group.full_name || group.name,
    full_name: group.full_name,
    automatic: group.automatic,
    flair_url: group.flair_url,
    flair_bg_color: group.flair_bg_color,
    flair_color: group.flair_color,
    isGroup: true,
  };
}

class AccessControlGranteeChooser extends EmailGroupUserChooser {
  valueProperty = "value";

  search(filter = "") {
    if (!filter) {
      return Promise.resolve(
        this.selectKit.options.customSearchOptions?.defaultSearchResults || []
      );
    }

    return ajax(ACCESS_CONTROL_GRANTEE_SEARCH_URL, {
      data: {
        term: filter,
        acl_target: this.selectKit.options.aclTarget,
      },
    })
      .then((results) => this.normalizeGranteeResults(results))
      .then((results) => this.excludeSelectedGrantees(results))
      .catch(() => []);
  }

  normalizeGranteeResults(results) {
    return [
      ...(results?.groups || []).map(groupGranteeResult),
      ...(results?.users || []).map((user) => this.userResult(user)),
    ];
  }

  userResult(user) {
    return {
      value: granteeValue("user", user.id),
      id: user.username,
      aclId: user.id,
      aclType: "user",
      name: user.name,
      username: user.username,
      showUserStatus: this.showUserStatus,
      status: user.status,
      avatar_template: user.avatar_template,
      isUser: true,
    };
  }

  excludeSelectedGrantees(results) {
    const excludedGrantees = this.selectKit.options.excludedGrantees || [];

    if (!excludedGrantees.length) {
      return results;
    }

    return results.filter((result) => !excludedGrantees.includes(result.value));
  }
}

const AccessControlPermissionTrigger = <template>
  <button
    type="button"
    class="btn btn-default d-access-control__permission"
    disabled={{@disabled}}
    ...attributes
  >
    <span class="d-button-label">
      {{@label}}
    </span>
    {{dIcon "angle-down"}}
  </button>
</template>;

export default class DAccessControl extends Component {
  @service site;

  constructor() {
    super(...arguments);
    this.permissionOptions = this.buildPermissionOptions();
  }

  /**
   * If a transformPermissionOptions function is provided, it is passed all
   * default permissions and can change the name, description, or level of
   * these options, OR add new options, returning the new array.
   *
   * The level property is used to sort the options, and is an indicator
   * of the level of access the permission provides, since e.g. Edit is a
   * higher level of access than View, and to Edit by definition you need
   * to be able to View.
   *
   * Otherwise, the default permissions are used.
   */
  buildPermissionOptions() {
    const permissions =
      this.args.transformPermissionOptions?.(defaultPermissions()) ||
      defaultPermissions();

    return [...permissions.sort((a, b) => a.level - b.level), REMOVE_ACTION];
  }

  get availableGroups() {
    const taken = new Set(this.selectedGroupIds);
    return (this.args.groups || [])
      .filter((group) => !taken.has(group.id))
      .sort((a, b) => {
        if (a.automatic !== b.automatic) {
          return a.automatic ? -1 : 1;
        }

        return (a.full_name || a.name).localeCompare(b.full_name || b.name);
      });
  }

  get availableGrantees() {
    return this.availableGroups.map(groupGranteeResult);
  }

  get selectedGranteeValues() {
    return this.acl.map((entry) => granteeValue(entry.type, entry.id));
  }

  get selectedGroupIds() {
    return this.acl
      .filter((entry) => entry.type === "group")
      .map((entry) => entry.id);
  }

  /**
   * Mandatory permissions are defined per-target server-side via a mandatory_acl
   * method, which is attached to the Site JSON. Any mandatory permissions will
   * be added to the ACL and cannot be removed or changed in the UI.
   */
  @cached
  get mandatoryAcl() {
    if (!this.args.aclTarget) {
      return [];
    }

    return this.site.access_control?.mandatory_acl?.[this.args.aclTarget] || [];
  }

  /**
   * Banned permissions are defined per-target server-side via a banned_acl
   * method, similar to mandatory_acl, which is attached to the Site JSON.
   * Any banned permisions will be filtered out, e.g. the `edit` permission might
   * be banned for the `anonymous_users` auto group ID.
   */
  @cached
  get bannedAcl() {
    if (!this.args.aclTarget) {
      return [];
    }

    return this.site.access_control?.banned_acl?.[this.args.aclTarget] || [];
  }

  /**
   * Construct the ACL for the target by combining the mandatory ACL with the
   * ACL passed in via args.  The ACL passed in via args will be whatever is
   * saved to the database for the target, so for new records this will be an
   * empty array.
   */
  get acl() {
    if (!this.mandatoryAcl.length) {
      return this.args.acl || [];
    }

    const mandatoryEntryKeys = new Set(
      this.mandatoryAcl.map((entry) => `${entry.type}-${entry.id}`)
    );
    const acl = (this.args.acl || []).filter(
      (entry) => !mandatoryEntryKeys.has(`${entry.type}-${entry.id}`)
    );

    this.mandatoryAcl.forEach((entry) => {
      if (entry.type === "group") {
        const group = (this.args.groups || []).find((g) => g.id === entry.id);
        if (group) {
          acl.push({
            type: "group",
            id: entry.id,
            name: group.name,
            display_name: group.full_name || group.name,
            flair_url: group.flair_url,
            flair_bg_color: group.flair_bg_color,
            flair_color: group.flair_color,
            permission: entry.permission,
            metadata: {
              auto_group: group.automatic,
            },
            mandatory: true,
          });
        }
      }
    });

    return acl;
  }

  // TODO (martin) How are we going to deal with users that have the Owner permission
  // here if we don't want to expose that in the UI?
  get rows() {
    return this.acl
      .map((entry) => ({
        key: `${entry.type}-${entry.id}-${entry.permission}`,
        id: entry.id,
        permission: entry.permission,
        display_name: entry.display_name,
        username: entry.username,
        name: entry.name,
        avatar_template: entry.avatar_template,
        flair_url: entry.flair_url,
        flair_bg_color: entry.flair_bg_color,
        flair_color: entry.flair_color,
        type: entry.type,
        mandatory: entry.mandatory,
      }))
      .sort((a, b) => {
        if (a.mandatory !== b.mandatory) {
          return a.mandatory ? -1 : 1;
        }

        const nameSort = (a.display_name || "").localeCompare(
          b.display_name || ""
        );

        if (a.mandatory && b.mandatory) {
          return nameSort;
        }

        if (a.type !== b.type) {
          return rowTypeSortOrder(a.type) - rowTypeSortOrder(b.type);
        }

        return nameSort;
      });
  }

  @action
  onGranteeChosen(_value, selectedGrantees) {
    const selectedGrantee = selectedGrantees?.[0];

    const isReadOnlyDefaultGroup =
      selectedGrantee.aclType === "group" &&
      READ_ONLY_DEFAULT_AUTO_GROUPS.includes(selectedGrantee.aclId);

    const newPermission = {
      id: selectedGrantee.aclId,
      display_name:
        selectedGrantee.name || selectedGrantee.full_name || selectedGrantee.id,
      type: selectedGrantee.aclType,
      permission: isReadOnlyDefaultGroup
        ? READ_ONLY_PERMISSION
        : EDIT_PERMISSION,
    };

    if (selectedGrantee.aclType === "group") {
      newPermission.name = selectedGrantee.id;
      newPermission.flair_url = selectedGrantee.flair_url;
      newPermission.flair_bg_color = selectedGrantee.flair_bg_color;
      newPermission.flair_color = selectedGrantee.flair_color;
      newPermission.metadata = {
        auto_group: selectedGrantee.automatic,
      };
    }

    if (selectedGrantee.aclType === "user") {
      newPermission.username = selectedGrantee.username;
      newPermission.name = selectedGrantee.name;
      newPermission.avatar_template = selectedGrantee.avatar_template;
    }

    const next = [...this.acl, newPermission];

    this.args.onChange(next);
  }

  @action
  onPermissionChange(granteeType, granteeId, permission) {
    if (permission === REMOVE_ACTION.id) {
      this.args.onChange(
        this.acl.filter(
          (entry) => !(entry.type === granteeType && entry.id === granteeId)
        )
      );
      return;
    }

    const next = this.acl.map((entry) =>
      entry.type === granteeType && entry.id === granteeId
        ? { ...entry, permission }
        : entry
    );

    this.args.onChange(next);
  }

  @action
  selectPermission(close, granteeType, granteeId, permission) {
    close?.();
    this.onPermissionChange(granteeType, granteeId, permission);
  }

  @action
  excludeBannedPermissions(permissions, grantee) {
    if (!this.bannedAcl.length) {
      return permissions;
    }

    return permissions.filter((permission) => {
      return !this.bannedAcl.some(
        (banned) =>
          banned.permission === permission.id &&
          banned.type === grantee.type &&
          banned.id === grantee.id
      );
    });
  }

  rowIsType(row, type) {
    return row.type === type;
  }

  rowAsUser(row) {
    return {
      username: row.username,
      id: row.id,
      name: row.name || row.display_name,
      avatar_template: row.avatar_template,
    };
  }

  @action
  permissionLabel(permissionId) {
    return (
      this.permissionOptions.find((option) => option.id === permissionId)
        ?.name || permissionId
    );
  }

  // TODO (martin) How are we going to deal with users that have the Owner permission
  // here if we don't want to expose that in the UI?

  <template>
    <div class="d-access-control">

      <AccessControlGranteeChooser
        class="d-access-control__chooser"
        @value={{null}}
        @onChange={{this.onGranteeChosen}}
        @labelProperty="name"
        @filterPlaceholder="access_control.manage.add_group"
        @options={{hash
          aclTarget=@aclTarget
          customSearchOptions=(hash defaultSearchResults=this.availableGrantees)
          excludedGrantees=this.selectedGranteeValues
          filterable=true
          includeGroups=true
          maximum=1
          none="access_control.manage.add_group"
        }}
      />
      {{#if this.rows.length}}
        <div class="d-access-control__rows">
          {{#each this.rows key="key" as |row|}}
            <div
              class={{dConcatClass
                "d-access-control__row"
                (if (eq row.type "user") "--user" "--group")
              }}
              data-row-type={{row.type}}
              data-row-id={{row.id}}
            >
              <span class="d-access-control__item">
                <span class="d-access-control__item-icon">
                  {{#if (this.rowIsType row "user")}}
                    {{dAvatar (this.rowAsUser row) imageSize="small"}}
                  {{/if}}
                  {{#if (this.rowIsType row "group")}}
                    {{dIcon "user-group"}}
                  {{/if}}
                </span>
                <span class="d-access-control__item-name">
                  {{row.display_name}}
                  {{#if row.mandatory}}
                    <DTooltip
                      @content={{i18n
                        "access_control.manage.mandatory_acl_tooltip"
                        name=row.display_name
                      }}
                    >
                      <:trigger>
                        <span class="d-access-control__tooltip">{{dIcon "lock"}}
                          Automatic</span>
                      </:trigger>
                    </DTooltip>
                  {{/if}}
                </span>
              </span>
              <DMenu
                @identifier="d-access-control__permission-menu"
                @modalForMobile={{true}}
                @autofocus={{false}}
                @triggerComponent={{component
                  AccessControlPermissionTrigger
                  label=(this.permissionLabel row.permission)
                  disabled=row.mandatory
                }}
                data-permission={{row.permission}}
              >
                <:content as |args|>
                  <DDropdownMenu as |dropdown|>
                    {{#each
                      (this.excludeBannedPermissions this.permissionOptions row)
                      key="id"
                      as |option|
                    }}
                      {{#if (eq option.id "remove")}}
                        <dropdown.divider />
                      {{/if}}
                      <dropdown.item>
                        <DButton
                          class={{dConcatClass
                            "d-access-control__permission-option"
                            "--with-description"
                            (if (eq option.id "remove") "--remove")
                            (if (eq option.id row.permission) "-selected")
                          }}
                          data-permission-id={{option.id}}
                          @action={{fn
                            this.selectPermission
                            args.close
                            row.type
                            row.id
                            option.id
                          }}
                        >
                          <div class="d-access-control__permission-texts">
                            <span class="d-access-control__permission-label">
                              {{option.name}}
                            </span>
                            {{#if option.description}}
                              <span
                                class="d-access-control__permission-description"
                              >
                                {{option.description}}
                              </span>
                            {{/if}}
                          </div>
                        </DButton>
                      </dropdown.item>
                    {{/each}}
                  </DDropdownMenu>
                </:content>
              </DMenu>
            </div>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
