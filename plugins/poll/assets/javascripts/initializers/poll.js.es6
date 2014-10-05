import PollController from "discourse/plugins/poll/controllers/poll";

var Poll = Discourse.Model.extend({
  post: null,
  options: [],
  closed: false,

  postObserver: function() {
    this.updateFromJson(this.get('post.poll_details'));
  }.observes('post.poll_details'),

  fetchNewPostDetails: function() {
    this.get('post.topic.postStream').triggerChangedPost(this.get('post.id'), this.get('post.topic.updated_at'));
  }.observes('post.topic.title'),

  updateFromJson: function(json) {
    var selectedOption = json["selected"];

    var options = [];
    Object.keys(json["options"]).forEach(function(option) {
      options.push(Ember.Object.create({
        option: option,
        votes: json["options"][option],
        checked: (option === selectedOption)
      }));
    });
    this.set('options', options);

    this.set('closed', json.closed);
  },

  saveVote: function(option) {
    this.get('options').forEach(function(opt) {
      opt.set('checked', opt.get('option') === option);
    });

    return Discourse.ajax("/poll", {
      type: "PUT",
      data: {post_id: this.get('post.id'), option: option}
    }).then(function(newJSON) {
      this.updateFromJson(newJSON);
    }.bind(this));
  }
});

var PollView = Ember.View.extend({
  templateName: "poll",
  classNames: ['poll-ui'],

  replaceElement: function(target) {
    this._insertElementLater(function() {
      target.replaceWith(this.$());
    });
  }
});

function initializePollView(self) {
  var post = self.get('post');
  var pollDetails = post.get('poll_details');

  var poll = Poll.create({post: post});
  poll.updateFromJson(pollDetails);

  var pollController = PollController.create({
    poll: poll,
    showResults: pollDetails["selected"],
    postController: self.get('controller')
  });

  var pollView = self.createChildView(PollView, {
    controller: pollController
  });
  return pollView;
}


export default {
  name: 'poll',

  initialize: function() {
    Discourse.PostView.reopen({
      createPollUI: function($post) {
        var post = this.get('post');

        if (!post.get('poll_details')) {
          return;
        }

        var view = initializePollView(this);

        var pollContainer = $post.find(".poll-ui:first");
        if (pollContainer.length === 0) {
          pollContainer = $post.find("ul:first");
        }

        view.replaceElement(pollContainer);
        this.set('pollView', view);

      }.on('postViewInserted'),

      clearPollView: function() {
        if (this.get('pollView')) {
          this.get('pollView').destroy();
        }
      }.on('willClearRender')
    });
  }
}
