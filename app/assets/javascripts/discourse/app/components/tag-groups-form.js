import Component from "@ember/component";
import Group from "discourse/models/group";
import I18n from "I18n";
import PermissionType from "discourse/models/permission-type";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { isEmpty } from "@ember/utils";

export default Component.extend(bufferedProperty("model"), {
  router: service(),
  dialog: service(),
  tagName: "",
  allGroups: null,

  init() {
    this._super(...arguments);
    this.setGroupOptions();
  },

  setGroupOptions() {
    Group.findAll().then((groups) => {
      this.set("allGroups", groups);
    });
  },

  @discourseComputed(
    "buffered.name",
    "buffered.tag_names",
    "buffered.permissions"
  )
  cannotSave(name, tagNames, permissions) {
    return (
      isEmpty(name) ||
      isEmpty(tagNames) ||
      (!this.everyoneSelected(permissions) &&
        isEmpty(this.selectedGroupNames(permissions)))
    );
  },

  @discourseComputed("buffered.permissions", "allGroups")
  selectedGroupIds(permissions, allGroups) {
    if (!permissions || !allGroups) {
      return [];
    }

    const selectedGroupNames = Object.keys(permissions);
    let groupIds = [];
    allGroups.forEach((group) => {
      if (selectedGroupNames.includes(group.name)) {
        groupIds.push(group.id);
      }
    });

    return groupIds;
  },

  everyoneSelected(permissions) {
    if (!permissions) {
      return true;
    }

    return permissions.everyone === PermissionType.FULL;
  },

  selectedGroupNames(permissions) {
    if (!permissions) {
      return [];
    }

    return Object.keys(permissions).filter((name) => name !== "everyone");
  },

  actions: {
    setPermissionsType(permissionName) {
      let updatedPermissions = Object.assign(
        {},
        this.buffered.get("permissions")
      );

      if (permissionName === "private") {
        delete updatedPermissions.everyone;
      } else if (permissionName === "visible") {
        updatedPermissions.everyone = PermissionType.READONLY;
      } else {
        updatedPermissions.everyone = PermissionType.FULL;
      }

      this.buffered.set("permissions", updatedPermissions);
    },

    setPermissionsGroups(groupIds) {
      let updatedPermissions = Object.assign(
        {},
        this.buffered.get("permissions")
      );

      this.allGroups.forEach((group) => {
        if (groupIds.includes(group.id)) {
          updatedPermissions[group.name] = PermissionType.FULL;
        } else {
          delete updatedPermissions[group.name];
        }
      });

      this.buffered.set("permissions", updatedPermissions);
    },

    save() {
      if (this.cannotSave) {
        this.dialog.alert(I18n.t("tagging.groups.cannot_save"));
        return false;
      }

      const attrs = this.buffered.getProperties(
        "name",
        "tag_names",
        "parent_tag_name",
        "one_per_topic",
        "permissions"
      );

      // If 'everyone' is set to full, we can remove any groups.
      if (
        !attrs.permissions ||
        attrs.permissions.everyone === PermissionType.FULL
      ) {
        attrs.permissions = { everyone: PermissionType.FULL };
      }

      this.model.save(attrs).then(() => {
        this.commitBuffer();

        if (this.onSave) {
          this.onSave();
        } else {
          this.router.transitionTo("tagGroups.index");
        }
      });
    },

    destroy() {
      return this.dialog.yesNoConfirm({
        message: I18n.t("tagging.groups.confirm_delete"),
        didConfirm: () => {
          this.model.destroyRecord().then(() => {
            if (this.onDestroy) {
              this.onDestroy();
            }
          });
        },
      });
    },
  },
});
