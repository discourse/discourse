import { sort } from "@ember/object/computed";
import EmberObject from "@ember/object";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
export default Controller.extend({
  sortedEmojis: sort("model", "emojiSorting"),

  init() {
    this._super(...arguments);

    this.emojiSorting = ["name"];
  },

  actions: {
    emojiUploaded(emoji) {
      emoji.url += "?t=" + new Date().getTime();
      this.model.pushObject(EmberObject.create(emoji));
    },

    destroy(emoji) {
      return bootbox.confirm(
        I18n.t("admin.emoji.delete_confirm", { name: emoji.get("name") }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        destroy => {
          if (destroy) {
            return ajax("/admin/customize/emojis/" + emoji.get("name"), {
              type: "DELETE"
            }).then(() => {
              this.model.removeObject(emoji);
            });
          }
        }
      );
    }
  }
});
