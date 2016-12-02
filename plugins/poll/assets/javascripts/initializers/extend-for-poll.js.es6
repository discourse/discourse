import { withPluginApi } from 'discourse/lib/plugin-api';
import { observes } from "ember-addons/ember-computed-decorators";

function createPollComponent(register, post, poll, vote) {
  const component = register.lookup("component:discourse-poll");
  component.setProperties({ model: poll, vote, post });
  return component;
}

let _pollViews;

function initializePolls(api) {

  const TopicController = api.container.lookupFactory('controller:topic');
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

  const Post = api.container.lookupFactory('model:post');
  Post.reopen({
    _polls: null,
    pollsObject: null,

    // we need a proper ember object so it is bindable
    @observes("polls")
    pollsChanged() {
      const polls = this.get("polls");
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
    }
  });

  function cleanUpPollViews() {
    if (_pollViews) {
      Object.keys(_pollViews).forEach(pollName => _pollViews[pollName].destroy());
    }
    _pollViews = null;
  }

  function createPollViews($elem, helper) {
    const $polls = $('.poll', $elem);
    if (!$polls.length) { return; }

    const post = helper.getModel();
    api.preventCloak(post.id);
    const votes = post.get('polls_votes') || {};

    post.pollsChanged();

    const polls = post.get("pollsObject");
    if (!polls) { return; }

    const postPollViews = {};

    $polls.each((idx, pollElem) => {
      const $div = $("<div>");
      const $poll = $(pollElem);

      const pollName = $poll.data("poll-name");
      const pollId = `${pollName}-${post.id}`;

      const pollComponent = createPollComponent(
        helper.register,
        post,
        polls[pollName],
        votes[pollName]
      );

      // Destroy a poll view if we're replacing it
      if (_pollViews && _pollViews[pollId]) {
        _pollViews[pollId].destroy();
      }

      $poll.replaceWith($div);
      Ember.run.scheduleOnce('afterRender', () => {
        pollComponent.renderer.appendTo(pollComponent, $div[0]);
      });

      postPollViews[pollId] = pollComponent;
    });

    _pollViews = postPollViews;
  }

  api.includePostAttributes("polls", "polls_votes");
  api.decorateCooked(createPollViews, { onlyStream: true });
  api.cleanupStream(cleanUpPollViews);
}

export default {
  name: "extend-for-poll",

  initialize() {
    withPluginApi('0.1', initializePolls);
  }
};
