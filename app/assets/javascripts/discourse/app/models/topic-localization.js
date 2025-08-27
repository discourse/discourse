import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class TopicLocalization extends RestModel {
  static createOrUpdate(topicId, locale, title) {
    return ajax("/topic_localizations/create_or_update", {
      type: "POST",
      data: {
        topic_id: topicId,
        locale,
        title,
      },
    });
  }

  static destroy(topicId, locale) {
    return ajax("/topic_localizations/destroy", {
      type: "DELETE",
      data: {
        topic_id: topicId,
        locale,
      },
    });
  }
}
