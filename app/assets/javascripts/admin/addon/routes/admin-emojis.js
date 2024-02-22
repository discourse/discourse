import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmojisRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/customize/emojis.json").then(function (emojis) {
      return emojis.map(function (emoji) {
        return EmberObject.create(emoji);
      });
    });
  }
}
