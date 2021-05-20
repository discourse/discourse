import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";

const TopicTimer = RestModel.extend({});

TopicTimer.reopenClass({
  update(
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
  },
});

export default TopicTimer;
