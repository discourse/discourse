import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { modifier } from "ember-modifier";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { prioritizeNameFallback } from "discourse/lib/settings";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelectPermission from "discourse/ui-kit/select/recipes/permissions/d-select-permission";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";
import DAccessControlGranteeChooser, {
  ACCESS_CONTROL_GRANTEE_SEARCH_URL,
  granteeValue,
  groupGranteeResult,
} from "./d-access-control/-internals/grantee-chooser.gjs";

/** The add box's keyboard control, in either select implementation. */
const CHOOSER_CONTROL =
  ".d-access-control__chooser input.d-select__input, .d-access-control__chooser .select-kit-header";

const EDIT_PERMISSION = "edit";
const OWNER_PERMISSION = "owner";
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

function ownerOption(target) {
  return {
    id: OWNER_PERMISSION,
    name: i18n("access_control.manage.access_permission_owner"),
    description: target
      ? i18n("access_control.manage.access_permission_owner_description", {
          target,
        })
      : undefined,
  };
}

export function defaultPermissions() {
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

export default class DAccessControl extends Component {
  @service a11y;
  @service site;
  @service siteSettings;

  registerRoot = modifier((element) => {
    this.#root = element;
    return () => (this.#root = null);
  });

  #root = null;

  constructor() {
    super(...arguments);
    this.permissionOptions = this.buildPermissionOptions();
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

    return (
      this.site.access_control?.mandatory_acl?.[
        this.args.aclTarget.key ?? this.args.aclTarget.type
      ] || []
    );
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

    return (
      this.site.access_control?.banned_acl?.[
        this.args.aclTarget.key ?? this.args.aclTarget.type
      ] || []
    );
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

  get rows() {
    const mappedAcl = this.acl.map((entry) => {
      const hydratedEntry = this.#hydrateDisplayName({ ...entry });

      return {
        key: granteeValue(hydratedEntry.type, hydratedEntry.id),
        id: hydratedEntry.id,
        permission: hydratedEntry.permission,
        display_name: hydratedEntry.display_name,
        sort_name:
          hydratedEntry.sort_name ||
          hydratedEntry.name ||
          hydratedEntry.display_name,
        username: hydratedEntry.username,
        name: hydratedEntry.name,
        avatar_template: hydratedEntry.avatar_template,
        type: hydratedEntry.type,
        mandatory:
          hydratedEntry.permission !== OWNER_PERMISSION &&
          Boolean(hydratedEntry.mandatory),
        owner: hydratedEntry.permission === OWNER_PERMISSION,
        permission_menu_disabled:
          hydratedEntry.permission === OWNER_PERMISSION
            ? !this.args.canManageOwners
            : Boolean(hydratedEntry.mandatory),
      };
    });

    return mappedAcl.sort((a, b) => {
      if (a.mandatory !== b.mandatory) {
        return a.mandatory ? -1 : 1;
      }

      if (a.owner !== b.owner) {
        return a.owner ? -1 : 1;
      }

      const nameSort = (a.sort_name || "").localeCompare(b.sort_name || "");

      if ((a.mandatory && b.mandatory) || (a.owner && b.owner)) {
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
    return this.availableGroups.map((group) =>
      groupGranteeResult(
        group,
        this.disabledGrantees.includes(granteeValue("group", group.id))
      )
    );
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
   * Grantees where it's impossible for them to be added because of a combination
   * of banned ACL rules, e.g. if the anonymous_users group cannot view, edit, or
   * manage. We disable so we can show a message/tooltip so it's not confusing
   * where the grantee went.
   */
  get disabledGrantees() {
    return this.availableGroups
      .filter((group) => {
        const availablePermissions = this.excludeBannedPermissions(
          this.permissionOptions,
          { type: "group", id: group.id }
        );

        return availablePermissions.length === 0;
      })
      .map((group) => granteeValue("group", group.id));
  }

  /** The group names and usernames already granted, which the add box leaves out. */
  get grantedNames() {
    return this.acl
      .map((entry) =>
        entry.type === "user"
          ? entry.username
          : (entry.name ??
            (this.args.groups || []).find(({ id }) => id === entry.id)?.name)
      )
      .filter(Boolean);
  }

  /** What the add box's results depend on, besides the granted names. */
  get granteeLoadContext() {
    return {
      aclTarget: this.args.aclTarget?.type,
      available: this.availableGroups.map(({ id }) => id),
      disabled: this.disabledGrantees,
    };
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
    const permissions = (
      this.args.transformPermissionOptions?.(defaultPermissions()) ||
      defaultPermissions()
    ).filter((permission) => permission.id !== OWNER_PERMISSION);

    return permissions.sort((a, b) => a.level - b.level);
  }

  /**
   * The add box's source: the groups that can still be added before anything is typed, then the
   * access control search for the target.
   */
  @action
  async loadGrantees(term) {
    if (!term) {
      return {
        groups: this.availableGroups.map((group) => this.#granteeGroup(group)),
      };
    }

    const results = await ajax(ACCESS_CONTROL_GRANTEE_SEARCH_URL, {
      data: { term, acl_target: this.args.aclTarget?.type },
    });
    return {
      users: results.users,
      groups: results.groups?.map((group) => this.#granteeGroup(group)),
    };
  }

  /**
   * Fired when a grantee is chosen from the DAccessControlGranteeChooser
   * search results, and by `onGranteePicked` for the new add box.
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
    this.#announceAdded(newPermission);
  }

  /** Adds a grantee picked in the add box, in the shape the legacy chooser emitted. */
  @action
  onGranteePicked(_value, record) {
    if (!record?.sourceId) {
      return;
    }

    this.onGranteeChosen(null, [
      record.type === "group"
        ? {
            aclId: record.sourceId,
            aclType: "group",
            id: record.id,
            full_name: record.fullName,
            automatic: record.automatic,
          }
        : {
            aclId: record.sourceId,
            aclType: "user",
            username: record.username,
            name: record.fullName,
            avatar_template: record.avatar_template,
          },
    ]);
  }

  @action
  onRowPermissionChange(granteeType, granteeId, permission) {
    const row = this.rows.find(
      (candidate) =>
        candidate.type === granteeType && candidate.id === granteeId
    );
    const next = this.acl.map((entry) =>
      entry.type === granteeType && entry.id === granteeId
        ? { ...entry, permission }
        : entry
    );

    this.args.onChange(next);
    if (row) {
      this.a11y.announce(
        i18n("access_control.manage.grantee_permission_changed", {
          name: row.display_name,
          permission: this.#permissionName(permission),
        })
      );
      // A new permission can move the row, and moving a node drops its focus.
      this.#focusAfterRender(this.#rowButtonSelector(row));
    }
  }

  @action
  onRowRemove(granteeType, granteeId) {
    const rows = this.rows;
    const index = rows.findIndex(
      (row) => row.type === granteeType && row.id === granteeId
    );
    const row = rows[index];

    this.args.onChange(
      this.acl.filter(
        (entry) => !(entry.type === granteeType && entry.id === granteeId)
      )
    );
    if (row) {
      this.a11y.announce(
        i18n("access_control.manage.grantee_removed", {
          name: row.display_name,
        })
      );
    }
    // The removed row's select had focus; the nearest row keeps the reader in the list.
    const neighbour = [
      ...rows.slice(index + 1),
      ...rows.slice(0, Math.max(index, 0)).reverse(),
    ].find((candidate) => !candidate.permission_menu_disabled);
    this.#focusAfterRender(
      neighbour ? this.#rowButtonSelector(neighbour) : CHOOSER_CONTROL
    );
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
  permissionOptionsFor(row) {
    const ownerOptionForTarget = ownerOption(this.args.aclTarget?.name);

    if (row.owner) {
      return [ownerOptionForTarget];
    }

    const permissionOptions = this.excludeBannedPermissions(
      this.permissionOptions,
      row
    );

    if (row.type === "user" && this.args.canManageOwners && !this.args.isNew) {
      return [...permissionOptions, ownerOptionForTarget];
    }

    return permissionOptions;
  }

  /** Tells screen readers who was added, since the new row appears away from the add box. */
  #announceAdded(grantee) {
    this.a11y.announce(
      i18n("access_control.manage.grantee_added", {
        name: grantee.display_name,
        permission: this.#permissionName(grantee.permission),
      })
    );
  }

  /** Focuses the first match inside this control once the change has rendered. */
  #focusAfterRender(selector) {
    schedule("afterRender", () => {
      this.#root?.querySelector(selector)?.focus();
    });
  }

  /** A group record for the add box, disabled when no permission can be granted to it. */
  #granteeGroup(group) {
    const disabled = this.disabledGrantees.includes(
      granteeValue("group", group.id)
    );
    return {
      ...group,
      disabled,
      disabledReason: disabled
        ? i18n("access_control.manage.disallowed")
        : undefined,
    };
  }

  #hydrateDisplayName(entry) {
    if (!isEmpty(entry.display_name)) {
      return entry;
    }

    if (entry.type === "group") {
      const group = (this.args.groups || []).find(({ id }) => id === entry.id);
      entry.display_name = group?.full_name || group?.name;
    } else if (entry.type === "user") {
      entry.display_name = prioritizeNameFallback(entry.name, entry.username);
    }

    return entry;
  }

  #permissionName(permission) {
    return (
      this.buildPermissionOptions().find(({ id }) => id === permission)?.name ??
      permission
    );
  }

  #rowButtonSelector(row) {
    return `.d-access-control__row[data-row-type="${row.type}"][data-row-id="${row.id}"] .d-access-control__permission`;
  }

  <template>
    <div class="d-access-control" {{this.registerRoot}}>
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectUser
          class="d-access-control__chooser"
          @exclude={{this.grantedNames}}
          @includeGroups="visible"
          @load={{this.loadGrantees}}
          @loadContext={{this.granteeLoadContext}}
          @onChange={{this.onGranteePicked}}
          @texts={{hash placeholder=(i18n "access_control.manage.add_group")}}
          @value={{null}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <DAccessControlGranteeChooser
          class="d-access-control__chooser"
          @filterPlaceholder="access_control.manage.add_group"
          @labelProperty="name"
          @onChange={{this.onGranteeChosen}}
          @options={{hash
            aclTargetType=@aclTarget.type
            customSearchOptions=(hash
              defaultSearchResults=this.defaultAvailableGrantees
            )
            excludedGrantees=this.excludedGrantees
            disabledGrantees=this.disabledGrantees
            filterable=true
            includeGroups=true
            maximum=1
            none="access_control.manage.add_group"
          }}
          @value={{null}}
        />
      {{/if}}
      {{#if (or this.rows.length (has-block "additionalRows"))}}
        <div class="d-access-control__rows">
          {{#each this.rows key="key" as |row|}}
            <div
              class={{dConcatClass
                "d-access-control__row"
                (if (eq row.type "user") "--user" "--group")
                (if row.mandatory "--mandatory")
                (if row.owner "--owner")
              }}
              data-row-id={{row.id}}
              data-row-type={{row.type}}
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
              <DSelectPermission
                class="d-access-control__permission"
                data-permission={{row.permission}}
                @disabled={{row.permission_menu_disabled}}
                @onChange={{fn this.onRowPermissionChange row.type row.id}}
                @onRemove={{fn this.onRowRemove row.type row.id}}
                @options={{this.permissionOptionsFor row}}
                @texts={{hash
                  ariaLabel=(i18n
                    "access_control.manage.grantee_permission"
                    name=row.display_name
                  )
                }}
                @value={{row.permission}}
              />
            </div>
          {{/each}}
          {{yield to="additionalRows"}}
        </div>
      {{/if}}
    </div>
  </template>
}
