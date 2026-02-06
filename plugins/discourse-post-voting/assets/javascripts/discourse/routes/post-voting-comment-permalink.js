import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class PostVotingCommentPermalinkRoute extends DiscourseRoute {
  async model(params) {
    const response = await ajax(
      `/post_voting/comments/${params.comment_id}.json`
    );

    return {
      topic: response.topic,
      comment: response.comment,
      post: response.post,
      comments: response.comments,
    };
  }

  titleToken() {
    return i18n("post_voting.comment.permalink.title");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setProperties({
      topic: model.topic,
      comment: model.comment,
      post: model.post,
      comments: model.comments,
    });
  }
}
