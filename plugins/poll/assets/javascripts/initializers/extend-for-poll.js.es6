import PostView from "discourse/views/post";
import { on } from "ember-addons/ember-computed-decorators";

function createPollView(container, post, poll, vote) {
  const controller = container.lookup("controller:poll", { singleton: false }),
        view = container.lookup("view:poll");

  controller.set("vote", vote);
  controller.setProperties({ model: Em.Object.create(poll), post });
  view.set("controller", controller);

  return view;
}

export default {
  name: "extend-for-poll",

  initialize(container) {

    const messageBus = container.lookup("message-bus:main");

    // listen for back-end to tell us when a post has a poll
    messageBus.subscribe("/polls", data => {
      const post = container.lookup("controller:topic").get('model.postStream').findLoadedPost(data.post_id);
      // HACK to trigger the "postViewUpdated" event
      Em.run.next(() => post.set("cooked", post.get("cooked") + " "));
    });

    // overwrite polls
    PostView.reopen({

      @on("postViewInserted", "postViewUpdated")
      _createPollViews($post) {
        const post = this.get("post"),
              polls = post.get("polls"),
              votes = post.get("polls_votes") || {};

        // don't even bother when there's no poll
        if (!polls) { return; }

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

        messageBus.subscribe(`/polls/${this.get("post.id")}`, results => {
          if (results && results.polls) {
            _.forEach(results.polls, poll => {
              if (pollViews[poll.name]) {
                pollViews[poll.name].get("controller").set("model", Em.Object.create(poll));
              }
            });
          }
        });

        this.set("pollViews", pollViews);
      },

      @on("willClearRender")
      _cleanUpPollViews() {
        messageBus.unsubscribe(`/polls/${this.get("post.id")}`);

        if (this.get("pollViews")) {
          _.forEach(this.get("pollViews"), v => v.destroy());
        }
      }
    });
  }
};
