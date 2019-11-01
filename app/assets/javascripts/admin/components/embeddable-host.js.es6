import { or } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import computed from "ember-addons/ember-computed-decorators";
import { on, observes } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend(bufferedProperty("host"), {
  editToggled: false,
  tagName: "tr",
  categoryId: null,

  editing: or("host.isNew", "editToggled"),

  @on("didInsertElement")
  @observes("editing")
  _focusOnInput() {
    schedule("afterRender", () => {
      this.element.querySelector(".host-name").focus();
    });
  },

  @computed("buffered.host", "host.isSaving")
  cantSave(host, isSaving) {
    return isSaving || Ember.isEmpty(host);
  },

  actions: {
    edit() {
      this.set("categoryId", this.get("host.category.id"));
      this.set("editToggled", true);
    },

    save() {
      if (this.cantSave) {
        return;
      }

      const props = this.buffered.getProperties(
        "host",
        "path_whitelist",
        "class_name"
      );
      props.category_id = this.categoryId;

      const host = this.host;

      host
        .save(props)
        .then(() => {
          host.set("category", Discourse.Category.findById(this.categoryId));
          this.set("editToggled", false);
        })
        .catch(popupAjaxError);
    },

    delete() {
      bootbox.confirm(I18n.t("admin.embedding.confirm_delete"), result => {
        if (result) {
          this.host.destroyRecord().then(() => {
            this.deleteHost(this.host);
          });
        }
      });
    },

    cancel() {
      const host = this.host;
      if (host.get("isNew")) {
        this.deleteHost(host);
      } else {
        this.rollbackBuffer();
        this.set("editToggled", false);
      }
    }
  }
});
