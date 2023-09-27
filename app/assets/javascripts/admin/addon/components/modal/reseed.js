import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

export default class Reseed extends Component {
  @service dialog;

  @tracked loading = true;
  @tracked reseeding = false;
  @tracked categories = null;
  @tracked topics = null;

  constructor() {
    super(...arguments);
    this.loadReseed();
  }

  @action
  async loadReseed() {
    try {
      const result = await ajax("/admin/customize/reseed");
      this.categories = result.categories;
      this.topics = result.topics;
    } finally {
      this.loading = false;
    }
  }

  _extractSelectedIds(items) {
    return items.filter((item) => item.selected).map((item) => item.id);
  }

  @action
  async reseed() {
    try {
      this.reseeding = true;
      await ajax("/admin/customize/reseed", {
        data: {
          category_ids: this._extractSelectedIds(this.categories),
          topic_ids: this._extractSelectedIds(this.topics),
        },
        type: "POST",
      });

      this.flash = null;
      this.args.closeModal();
    } catch {
      this.flash = I18n.t("generic_error");
    } finally {
      this.reseeding = false;
    }
  }
}
