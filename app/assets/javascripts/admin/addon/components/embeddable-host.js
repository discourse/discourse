import Component from "@ember/component";
import { action } from "@ember/object";
import { or } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import Category from "discourse/models/category";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@tagName("tr")
export default class EmbeddableHost extends Component.extend(
  bufferedProperty("host")
) {
  @service dialog;
  editToggled = false;
  categoryId = null;
  category = null;
  tags = null;
  user = null;

  @or("host.isNew", "editToggled") editing;

  init() {
    super.init(...arguments);

    const host = this.host;
    const categoryId = host.category_id || this.site.uncategorized_category_id;
    const category = Category.findById(categoryId);

    this.set("category", category);
    this.set("tags", host.tags || []);
    this.set("user", host.user);
  }

  @discourseComputed("buffered.host", "host.isSaving")
  cantSave(host, isSaving) {
    return isSaving || isEmpty(host);
  }

  @action
  edit() {
    this.set("editToggled", true);
  }

  @action
  onUserChange(user) {
    this.set("user", user);
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
    props.category_id = this.category.id;
    props.tags = this.tags;
    props.user =
      Array.isArray(this.user) && this.user.length > 0 ? this.user[0] : null;

    const host = this.host;

    host
      .save(props)
      .then(() => {
        this.set("editToggled", false);
      })
      .catch(popupAjaxError);
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("admin.embedding.confirm_delete"),
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
