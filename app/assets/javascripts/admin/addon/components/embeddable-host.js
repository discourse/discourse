import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

@tagName("tr")
@classNames("d-admin-row__content")
export default class EmbeddableHost extends Component {
  @service dialog;
  category = null;
  tags = null;
  user = null;

  init() {
    super.init(...arguments);

    const host = this.host;
    const categoryId = host.category_id || this.site.uncategorized_category_id;
    const category = Category.findById(categoryId);

    this.set("category", category);
    this.set("tags", (host.tags || []).join(", "));
    this.set("user", host.user);
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
}
