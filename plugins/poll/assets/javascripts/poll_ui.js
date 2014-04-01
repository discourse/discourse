var Poll = Discourse.Model.extend({
  post: null,
  options: [],

  postObserver: function() {
    this.updateOptionsFromJson(this.get('post.poll_details'));
  }.observes('post.poll_details'),

  updateOptionsFromJson: function(json) {
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
  },

  saveVote: function(option) {
    this.get('options').forEach(function(opt) {
      opt.set('checked', opt.get('option') === option);
    });

    return Discourse.ajax("/poll", {
      type: "PUT",
      data: {post_id: this.get('post.id'), option: option}
    }).then(function(newJSON) {
      this.updateOptionsFromJson(newJSON);
    }.bind(this));
  }
});

var PollController = Discourse.Controller.extend({
  poll: null,
  showResults: false,

  disableRadio: Em.computed.any('poll.post.topic.closed', 'loading'),

  actions: {
    selectOption: function(option) {
      if (this.get('disableRadio')) {
        return;
      }

      if (!this.get('currentUser.id')) {
        this.get('postController').send('showLogin');
        return;
      }

      this.set('loading', true);
      this.get('poll').saveVote(option).then(function() {
        this.set('loading', false);
        this.set('showResults', true);
      }.bind(this));
    },

    toggleShowResults: function() {
      this.set('showResults', !this.get('showResults'));
    }
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
  poll.updateOptionsFromJson(pollDetails);

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
