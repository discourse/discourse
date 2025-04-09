import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import WatchedWord from "admin/models/watched-word";

export default class AdminWatchedWordsRoute extends DiscourseRoute {
  queryParams = {
    filter: { replace: true },
  };

  titleToken() {
    return i18n("admin.config.watched_words.title");
  }

  model() {
    return WatchedWord.findAll();
  }

  afterModel(model) {
    const controller = this.controllerFor("adminWatchedWords");
    controller.set("allWatchedWords", model);
  }
}
