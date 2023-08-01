import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";

export default class AdminReseedController extends Controller.extend(
  ModalFunctionality
) {
  @service dialog;

  loading = true;
  reseeding = false;
  categories = null;
  topics = null;

  onShow() {
    ajax("/admin/customize/reseed")
      .then((result) => {
        this.setProperties({
          categories: result.categories,
          topics: result.topics,
        });
      })
      .finally(() => this.set("loading", false));
  }

  _extractSelectedIds(items) {
    return items.filter((item) => item.selected).map((item) => item.id);
  }

  @action
  reseed() {
    this.set("reseeding", true);
    ajax("/admin/customize/reseed", {
      data: {
        category_ids: this._extractSelectedIds(this.categories),
        topic_ids: this._extractSelectedIds(this.topics),
      },
      type: "POST",
    })
      .catch(() => this.dialog.alert(I18n.t("generic_error")))
      .finally(() => {
        this.set("reseeding", false);
        this.send("closeModal");
      });
  }
}
