import WatchedWord from "discourse/admin/models/watched-word";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminWatchedWordsRoute extends DiscourseRoute {
  queryParams = {
    filter: { replace: true },
  };

  titleToken() {
    return i18n("admin.config.watched_words.title");
  }

  /** @returns {any} */
  model() {
    return WatchedWord.findAll();
  }

  setupController(controller, model) {
    controller.setProperties({
      allWatchedWords: model,
      filteredWatchedWords: model,
    });
  }
}
