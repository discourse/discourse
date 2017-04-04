import { ajax } from 'discourse/lib/ajax';
import RestModel from 'discourse/models/rest';

const TopicStatusUpdate = RestModel.extend({});

TopicStatusUpdate.reopenClass({
  updateStatus(topicId, time, basedOnLastPost, statusType, categoryId) {
    let data = {
      time: time,
      timezone_offset: (new Date().getTimezoneOffset()),
      status_type: statusType
    };

    if (basedOnLastPost) data.based_on_last_post = basedOnLastPost;
    if (categoryId) data.category_id = categoryId;

    return ajax({
      url: `/t/${topicId}/status_update`,
      type: 'POST',
      data
    });
  }
});

export default TopicStatusUpdate;
