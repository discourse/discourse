import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmojisRoute extends DiscourseRoute {
  async model() {
    const emojis = await ajax("/admin/customize/emojis.json");
    return emojis.map((emoji) => EmberObject.create(emoji));
  }
}
