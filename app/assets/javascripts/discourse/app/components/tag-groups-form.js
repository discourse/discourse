import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import PermissionType from "discourse/models/permission-type";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@tagName("")
export default class TagGroupsForm extends Component.extend(
  bufferedProperty("model")
) {
  @service router;
  @service dialog;
  @service site;

  // All but the "everyone" group
  allGroups = this.site.groups.filter(({ id }) => id !== 0);

  @discourseComputed("buffered.permissions")
  selectedGroupIds(permissions) {
    if (!permissions) {
      return [];
    }

    let groupIds = [];

    for (const [groupId, permission] of Object.entries(permissions)) {
      // JS object keys are always strings, so we need to convert them to integers
      const id = parseInt(groupId, 10);

      if (id !== 0 && permission === PermissionType.FULL) {
        groupIds.push(id);
      }
    }

    return groupIds;
  }

  @action
  setPermissionsGroups(groupIds) {
    let permissions = {};
    groupIds.forEach((id) => (permissions[id] = PermissionType.FULL));
    this.buffered.set("permissions", permissions);
  }

  @action
  save() {
    const attrs = this.buffered.getProperties(
      "name",
      "tag_names",
      "parent_tag_name",
      "one_per_topic",
      "permissions"
    );

    if (isEmpty(attrs.name)) {
      this.dialog.alert("tagging.groups.cannot_save.empty_name");
      return false;
    }

    if (isEmpty(attrs.tag_names)) {
      this.dialog.alert("tagging.groups.cannot_save.no_tags");
      return false;
    }

    attrs.permissions ??= {};

    const permissionName = this.buffered.get("permissionName");

    if (permissionName === "public") {
      attrs.permissions = { 0: PermissionType.FULL };
    } else if (permissionName === "visible") {
      attrs.permissions[0] = PermissionType.READONLY;
    } else if (permissionName === "private") {
      delete attrs.permissions[0];
    } else {
      this.dialog.alert("tagging.groups.cannot_save.no_groups");
      return false;
    }

    this.model.save(attrs).then(() => this.onSave?.());
  }

  @action
  destroyTagGroup() {
    return this.dialog.yesNoConfirm({
      message: i18n("tagging.groups.confirm_delete"),
      didConfirm: () =>
        this.model.destroyRecord().then(() => this.onDestroy?.()),
    });
  }
}
