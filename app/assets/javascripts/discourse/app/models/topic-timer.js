import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class TopicTimer extends RestModel {
  static update(
    topicId,
    time,
    basedOnLastPost,
    statusType,
    categoryId,
    durationMinutes
  ) {
    let data = {
      time,
      status_type: statusType,
    };

    if (basedOnLastPost) {
      data.based_on_last_post = basedOnLastPost;
    }
    if (categoryId) {
      data.category_id = categoryId;
    }
    if (durationMinutes) {
      data.duration_minutes = durationMinutes;
    }

    return ajax({
      url: `/t/${topicId}/timer`,
      type: "POST",
      data,
    });
  }
}
