import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend(ModalFunctionality, {
  loading: true,
  reseeding: false,
  categories: null,
  topics: null,

  onShow() {
    ajax("/admin/customize/reseed")
      .then(result => {
        this.setProperties({
          categories: result.categories,
          topics: result.topics
        });
      })
      .finally(() => this.set("loading", false));
  },

  _extractSelectedIds(items) {
    return items.filter(item => item.selected).map(item => item.id);
  },

  actions: {
    reseed() {
      this.set("reseeding", true);
      ajax("/admin/customize/reseed", {
        data: {
          category_ids: this._extractSelectedIds(this.categories),
          topic_ids: this._extractSelectedIds(this.topics)
        },
        method: "POST"
      })
        .then(
          () => this.send("closeModal"),
          () => bootbox.alert(I18n.t("generic_error"))
        )
        .finally(() => this.set("reseeding", false));
    }
  }
});
