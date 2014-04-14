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

var PollController = Discourse.Controller.extend({
  poll: null,
  showResults: Em.computed.oneWay('poll.closed'),
  disableRadio: Em.computed.any('poll.closed', 'loading'),
  showToggleClosePoll: function() {
    return this.get('poll.post.topic.details.can_edit') && !Discourse.SiteSettings.allow_user_locale;
  }.property('poll.post.topic.details.can_edit'),

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
    },

    toggleClosePoll: function() {
      this.set('loading', true);
      return Discourse.ajax("/poll/toggle_close", {
        type: "PUT",
        data: {post_id: this.get('poll.post.id')}
      }).then(function(topicJson) {
        this.set('poll.post.topic.title', topicJson.basic_topic.title);
        this.set('poll.post.topic.fancy_title', topicJson.basic_topic.title);
        this.set('loading', false);
      }.bind(this));
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
