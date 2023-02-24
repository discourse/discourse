import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

export default Modal.extend({
  dialog: service(),
  loading: true,
  reseeding: false,
  categories: null,
  topics: null,

  onShow() {
    ajax("/admin/customize/reseed")
      .then((result) => {
        this.setProperties({
          categories: result.categories,
          topics: result.topics,
        });
      })
      .finally(() => this.set("loading", false));
  },

  _extractSelectedIds(items) {
    return items.filter((item) => item.selected).map((item) => item.id);
  },

  actions: {
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
    },
  },
});
