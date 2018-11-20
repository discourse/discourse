import { bufferedProperty } from "discourse/mixins/buffered-content";
import computed from "ember-addons/ember-computed-decorators";
import { on, observes } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Component.extend(bufferedProperty("host"), {
  editToggled: false,
  tagName: "tr",
  categoryId: null,

  editing: Ember.computed.or("host.isNew", "editToggled"),

  @on("didInsertElement")
  @observes("editing")
  _focusOnInput() {
    Ember.run.schedule("afterRender", () => {
      this.$(".host-name").focus();
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
      if (this.get("cantSave")) {
        return;
      }

      const props = this.get("buffered").getProperties(
        "host",
        "path_whitelist",
        "class_name"
      );
      props.category_id = this.get("categoryId");

      const host = this.get("host");

      host
        .save(props)
        .then(() => {
          host.set(
            "category",
            Discourse.Category.findById(this.get("categoryId"))
          );
          this.set("editToggled", false);
        })
        .catch(popupAjaxError);
    },

    delete() {
      bootbox.confirm(I18n.t("admin.embedding.confirm_delete"), result => {
        if (result) {
          this.get("host")
            .destroyRecord()
            .then(() => {
              this.sendAction("deleteHost", this.get("host"));
            });
        }
      });
    },

    cancel() {
      const host = this.get("host");
      if (host.get("isNew")) {
        this.sendAction("deleteHost", host);
      } else {
        this.rollbackBuffer();
        this.set("editToggled", false);
      }
    }
  }
});
