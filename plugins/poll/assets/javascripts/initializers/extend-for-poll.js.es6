import PostView from "discourse/views/post";
import TopicController from "discourse/controllers/topic";
import Post from "discourse/models/post";

import { on } from "ember-addons/ember-computed-decorators";

function createPollView(container, post, poll, vote) {
  const controller = container.lookup("controller:poll", { singleton: false }),
        view = container.lookup("view:poll");

  controller.set("vote", vote);
  controller.setProperties({ model: poll, post });
  view.set("controller", controller);

  return view;
}

export default {
  name: "extend-for-poll",

  initialize(container) {

    Post.reopen({
      // we need a proper ember object so it is bindable
      pollsChanged: function(){
        const polls  = this.get("polls");
        if (polls) {
          this._polls = this._polls || {};
          _.map(polls, (v,k) => {
            const existing = this._polls[k];
            if (existing) {
              this._polls[k].setProperties(v);
            } else {
              this._polls[k] = Em.Object.create(v);
            }
          });
          this.set("pollsObject", this._polls);
        }
      }.observes("polls")
    });

    TopicController.reopen({
      subscribe(){
          this._super();
          this.messageBus.subscribe("/polls/" + this.get("model.id"), msg => {
            const post = this.get('model.postStream').findLoadedPost(msg.post_id);
            if (post) {
              post.set('polls', msg.polls);
            }
        });
      },
      unsubscribe(){
        this.messageBus.unsubscribe('/polls/*');
        this._super();
      }
    });

    // overwrite polls
    PostView.reopen({

      @on("postViewInserted", "postViewUpdated")
      _createPollViews($post) {
        const post = this.get("post"),
              votes = post.get("polls_votes") || {};

        post.pollsChanged();
        const polls = post.get("pollsObject");

        // don't even bother when there's no poll
        if (!polls) { return; }

        // TODO inject cleanly into 

        // clean-up if needed
        this._cleanUpPollViews();

        const pollViews = {};

        // iterate over all polls
        $(".poll", $post).each(function() {
          const $div = $("<div>"),
                $poll = $(this),
                pollName = $poll.data("poll-name"),
                pollView = createPollView(container, post, polls[pollName], votes[pollName]);

          $poll.replaceWith($div);
          Em.run.next(() => pollView.renderer.replaceIn(pollView, $div[0]));
          pollViews[pollName] = pollView;
        });

        this.set("pollViews", pollViews);
      },

      @on("willClearRender")
      _cleanUpPollViews() {
        if (this.get("pollViews")) {
          _.forEach(this.get("pollViews"), v => v.destroy());
        }
      }
    });
  }
};
