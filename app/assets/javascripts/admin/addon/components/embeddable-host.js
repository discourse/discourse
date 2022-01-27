import Category from "discourse/models/category";
import Component from "@ember/component";
import I18n from "I18n";
import bootbox from "bootbox";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { or } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend(bufferedProperty("host"), {
  editToggled: false,
  tagName: "tr",
  categoryId: null,
  category: null,

  editing: or("host.isNew", "editToggled"),

  init() {
    this._super(...arguments);

    const host = this.host;
    const categoryId = host.category_id || this.site.uncategorized_category_id;
    const category = Category.findById(categoryId);

    host.set("category", category);
  },

  @discourseComputed("buffered.host", "host.isSaving")
  cantSave(host, isSaving) {
    return isSaving || isEmpty(host);
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
        "allowed_paths",
        "class_name"
      );
      props.category_id = this.categoryId;

      const host = this.host;

      host
        .save(props)
        .then(() => {
          host.set("category", Category.findById(this.categoryId));
          this.set("editToggled", false);
        })
        .catch(popupAjaxError);
    },

    delete() {
      bootbox.confirm(I18n.t("admin.embedding.confirm_delete"), (result) => {
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
    },
  },
});
