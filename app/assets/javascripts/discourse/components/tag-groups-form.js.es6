import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import PermissionType from "discourse/models/permission-type";

export default Component.extend(bufferedProperty("model"), {
  tagName: "",

  @computed("buffered.isSaving", "buffered.name", "buffered.tag_names")
  savingDisabled(isSaving, name, tagNames) {
    return isSaving || Ember.isEmpty(name) || Ember.isEmpty(tagNames);
  },

  actions: {
    setPermissions(permissionName) {
      if (permissionName === "private") {
        this.buffered.set("permissions", {
          staff: PermissionType.FULL
        });
      } else if (permissionName === "visible") {
        this.buffered.set("permissions", {
          staff: PermissionType.FULL,
          everyone: PermissionType.READONLY
        });
      } else {
        this.buffered.set("permissions", {
          everyone: PermissionType.FULL
        });
      }
    },

    save() {
      const attrs = this.buffered.getProperties(
        "name",
        "tag_names",
        "parent_tag_name",
        "one_per_topic",
        "permissions"
      );

      this.model.save(attrs).then(() => {
        this.commitBuffer();

        if (this.onSave) {
          this.onSave();
        }
      });
    },

    destroy() {
      return bootbox.confirm(
        I18n.t("tagging.groups.confirm_delete"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        destroy => {
          if (!destroy) {
            return;
          }

          this.model.destroyRecord().then(() => {
            if (this.onDestroy) {
              this.onDestroy();
            }
          });
        }
      );
    }
  }
});
