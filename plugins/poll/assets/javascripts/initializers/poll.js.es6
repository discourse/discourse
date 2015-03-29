import Poll from "discourse/plugins/poll/models/poll";
import PollView from "discourse/plugins/poll/views/poll";
import PollController from "discourse/plugins/poll/controllers/poll";

import PostView from "discourse/views/post";

function initializePollView(self) {
  const post = self.get('post'),
        pollDetails = post.get('poll_details');

  let poll = Poll.create({ post: post });
  poll.updateFromJson(pollDetails);

  const pollController = PollController.create({
    poll: poll,
    showResults: pollDetails["selected"],
    postController: self.get('controller')
  });

  return self.createChildView(PollView, { controller: pollController });
}

export default {
  name: 'poll',

  initialize: function() {
    PostView.reopen({
      createPollUI: function($post) {
        if (!this.get('post').get('poll_details')) {
          return;
        }

        let view = initializePollView(this),
            pollContainer = $post.find(".poll-ui:first");

        if (pollContainer.length === 0) {
          pollContainer = $post.find("ul:first");
        }

        let $div = $('<div>');
        pollContainer.replaceWith($div);
        view.constructor.renderer.appendTo(view, $div[0]);
        this.set('pollView', view);
      }.on('postViewInserted'),

      clearPollView: function() {
        if (this.get('pollView')) { this.get('pollView').destroy(); }
      }.on('willClearRender')
    });
  }
};
