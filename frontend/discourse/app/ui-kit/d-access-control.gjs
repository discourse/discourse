import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DAccessControlGranteeChooser, {
  granteeValue,
  groupGranteeResult,
} from "./d-access-control-grantee-chooser";

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

function rowTypeSortOrder(type) {
  return ROW_TYPE_SORT_ORDER[type] ?? 2;
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
      this.mandatoryAcl.map((entry) => granteeValue(entry.type, entry.id))
    );

    // The passed in ACL (if any) without the mandatory entries, which are
    // added back in below.
    const resolvedAcl = (this.args.acl || []).filter(
      (entry) => !mandatoryEntryKeys.has(granteeValue(entry.type, entry.id))
    );

    this.mandatoryAcl.forEach((entry) => {
      // NOTE (martin) This is groups only for now...not sure we will need mandatory
      // user ACLs, but we can figure that out later.
      if (entry.type === "group") {
        const group = (this.args.groups || []).find((g) => g.id === entry.id);
        if (group) {
          resolvedAcl.push({
            type: "group",
            id: entry.id,
            name: group.name,
            display_name: group.full_name || group.name,
            permission: entry.permission,
            metadata: {
              auto_group: group.automatic,
            },
            mandatory: true,
          });
        }
      }
    });

    return resolvedAcl;
  }

  // TODO (martin) How are we going to deal with users that have the Owner permission
  // here if we don't want to expose that in the UI?
  get rows() {
    const mappedAcl = this.acl.map((entry) => ({
      key: `${granteeValue(entry.type, entry.id)}:${entry.permission}`,
      id: entry.id,
      permission: entry.permission,
      display_name: entry.display_name,
      sort_name: entry.sort_name || entry.name || entry.display_name,
      username: entry.username,
      name: entry.name,
      avatar_template: entry.avatar_template,
      type: entry.type,
      mandatory: Boolean(entry.mandatory),
    }));

    return mappedAcl.sort((a, b) => {
      if (a.mandatory !== b.mandatory) {
        return a.mandatory ? -1 : 1;
      }

      const nameSort = (a.sort_name || "").localeCompare(b.sort_name || "");

      if (a.mandatory && b.mandatory) {
        return nameSort;
      }

      if (a.type !== b.type) {
        return rowTypeSortOrder(a.type) - rowTypeSortOrder(b.type);
      }

      return nameSort;
    });
  }

  /**
   * The default available grantees which are shown in the preloaded
   * search results for DAccessControlGranteeChooser. This is used to show
   * the available groups which can be added to the ACL, with users
   * gated behind an async search request.
   */
  get defaultAvailableGrantees() {
    return this.availableGroups.map(groupGranteeResult);
  }

  get availableGroups() {
    const takenGroupIds = new Set(
      this.acl
        .filter((entry) => entry.type === "group")
        .map((entry) => entry.id)
    );

    return (this.args.groups || [])
      .filter((group) => !takenGroupIds.has(group.id))
      .sort((a, b) => {
        if (a.automatic !== b.automatic) {
          return a.automatic ? -1 : 1;
        }

        return (a.full_name || a.name).localeCompare(b.full_name || b.name);
      });
  }

  /**
   * Grantees which should not show in the search results for
   * DAccessControlGranteeChooser. This is used to prevent users from adding the
   * same grantee (a user or group) multiple times.
   */
  get excludedGrantees() {
    return this.acl.map((entry) => granteeValue(entry.type, entry.id));
  }

  /**
   * Fired when a grantee is chosen from the DAccessControlGranteeChooser
   * search results.
   */
  @action
  onGranteeChosen(_value, selectedGrantees) {
    const selectedGrantee = selectedGrantees?.[0];

    const isReadOnlyDefaultGroup =
      selectedGrantee.aclType === "group" &&
      READ_ONLY_DEFAULT_AUTO_GROUPS.includes(selectedGrantee.aclId);

    const newPermission = {
      id: selectedGrantee.aclId,
      type: selectedGrantee.aclType,
      permission: isReadOnlyDefaultGroup
        ? READ_ONLY_PERMISSION
        : EDIT_PERMISSION,
    };

    if (selectedGrantee.aclType === "group") {
      newPermission.name = selectedGrantee.id;
      newPermission.display_name =
        selectedGrantee.full_name || selectedGrantee.id;
      newPermission.metadata = {
        auto_group: selectedGrantee.automatic,
      };
    }

    if (selectedGrantee.aclType === "user") {
      const sortName =
        selectedGrantee.sort_name ||
        selectedGrantee.name ||
        selectedGrantee.display_name ||
        selectedGrantee.username;

      newPermission.username = selectedGrantee.username;
      newPermission.name = selectedGrantee.name;
      newPermission.sort_name = sortName;
      newPermission.display_name = prioritizeNameFallback(
        selectedGrantee.name,
        selectedGrantee.username
      );
      newPermission.avatar_template = selectedGrantee.avatar_template;
    }

    const next = [...this.acl, newPermission];

    this.args.onChange(next);
  }

  @action
  onRowPermissionChange(close, granteeType, granteeId, permission) {
    close?.();

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

  /**
   * Certain ACL permissions are banned so we need to filter these out
   * based on grantee type and the available permissions for a row.
   */
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

  @action
  permissionLabel(permissionId) {
    return this.permissionOptions.find((option) => option.id === permissionId)
      .name;
  }

  // TODO (martin) How are we going to deal with users that have the Owner permission
  // here if we don't want to expose that in the UI?

  <template>
    <div class="d-access-control">
      <DAccessControlGranteeChooser
        class="d-access-control__chooser"
        @value={{null}}
        @onChange={{this.onGranteeChosen}}
        @labelProperty="name"
        @filterPlaceholder="access_control.manage.add_group"
        @options={{hash
          aclTarget=@aclTarget
          customSearchOptions=(hash
            defaultSearchResults=this.defaultAvailableGrantees
          )
          excludedGrantees=this.excludedGrantees
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
                (if row.mandatory "--mandatory")
              }}
              data-row-type={{row.type}}
              data-row-id={{row.id}}
            >
              <span class="d-access-control__item">
                <span class="d-access-control__item-icon">
                  {{#if (eq row.type "user")}}
                    {{dAvatar row imageSize="small"}}
                  {{/if}}
                  {{#if (eq row.type "group")}}
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
                          {{i18n "access_control.manage.mandatory"}}
                        </span>
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
                            this.onRowPermissionChange
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
