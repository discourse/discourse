import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import computed from "ember-addons/ember-computed-decorators";
import PermissionType from "discourse/models/permission-type";

export default RestModel.extend({
  @computed("name", "tag_names", "saving")
  disableSave(name, tagNames, saving) {
    return saving || Ember.isEmpty(name) || Ember.isEmpty(tagNames);
  },

  @computed("permissions")
  permissionName: {
    get(permissions) {
      if (!permissions) return "public";

      if (permissions["everyone"] === PermissionType.FULL) {
        return "public";
      } else if (permissions["everyone"] === PermissionType.READONLY) {
        return "visible";
      } else {
        return "private";
      }
    },

    set(value) {
      if (value === "private") {
        this.set("permissions", { staff: PermissionType.FULL });
      } else if (value === "visible") {
        this.set("permissions", {
          staff: PermissionType.FULL,
          everyone: PermissionType.READONLY
        });
      } else {
        this.set("permissions", { everyone: PermissionType.FULL });
      }
    }
  },

  save() {
    this.set("savingStatus", I18n.t("saving"));
    this.set("saving", true);

    const isNew = this.get("id") === "new";
    const url = isNew ? "/tag_groups" : `/tag_groups/${this.get("id")}`;
    const data = this.getProperties(
      "name",
      "tag_names",
      "parent_tag_name",
      "one_per_topic",
      "permissions"
    );

    return ajax(url, {
      data,
      type: isNew ? "POST" : "PUT"
    })
      .then(result => {
        if (result.tag_group && result.tag_group.id) {
          this.set("id", result.tag_group.id);
        }
      })
      .finally(() => {
        this.set("savingStatus", I18n.t("saved"));
        this.set("saving", false);
      });
  },

  destroy() {
    return ajax(`/tag_groups/${this.get("id")}`, { type: "DELETE" });
  }
});
