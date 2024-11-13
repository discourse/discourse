import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminEmojisRoute extends DiscourseRoute {
  titleToken() {
    return I18n.t("admin.emoji.title");
  }

  async model() {
    const emojis = await ajax("/admin/customize/emojis.json");
    return emojis.map((emoji) => EmberObject.create(emoji));
  }
}
