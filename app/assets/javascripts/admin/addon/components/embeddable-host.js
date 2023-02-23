import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import { inject as service } from "@ember/service";
import { or } from "@ember/object/computed";
import Category from "discourse/models/category";
import Component from "@ember/component";
import I18n from "I18n";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";

@tagName("tr")
export default class EmbeddableHost extends Component.extend(
  bufferedProperty("host")
) {
  @service dialog;
  editToggled = false;
  categoryId = null;
  category = null;

  @or("host.isNew", "editToggled") editing;

  constructor() {
    super(...arguments);

    const host = this.host;
    const categoryId = host.category_id || this.site.uncategorized_category_id;
    const category = Category.findById(categoryId);

    host.set("category", category);
  }

  @discourseComputed("buffered.host", "host.isSaving")
  cantSave(host, isSaving) {
    return isSaving || isEmpty(host);
  }

  @action
  edit() {
    this.set("categoryId", this.get("host.category.id"));
    this.set("editToggled", true);
  }

  @action
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
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: I18n.t("admin.embedding.confirm_delete"),
      didConfirm: () => {
        return this.host.destroyRecord().then(() => {
          this.deleteHost(this.host);
        });
      },
    });
  }

  @action
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
