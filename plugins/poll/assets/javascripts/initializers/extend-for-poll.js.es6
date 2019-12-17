import { withPluginApi } from "discourse/lib/plugin-api";
import { observes } from "discourse-common/utils/decorators";
import { getRegister } from "discourse-common/lib/get-owner";
import WidgetGlue from "discourse/widgets/glue";

function initializePolls(api) {
  const register = getRegister(api);

  api.modifyClass("controller:topic", {
    subscribe() {
      this._super(...arguments);
      this.messageBus.subscribe("/polls/" + this.get("model.id"), msg => {
        const post = this.get("model.postStream").findLoadedPost(msg.post_id);
        if (post) {
          post.set("polls", msg.polls);
        }
      });
    },
    unsubscribe() {
      this.messageBus.unsubscribe("/polls/*");
      this._super(...arguments);
    }
  });

  let _glued = [];
  let _interval = null;

  function rerender() {
    _glued.forEach(g => g.queueRerender());
  }

  api.modifyClass("model:post", {
    _polls: null,
    pollsObject: null,

    // we need a proper ember object so it is bindable
    @observes("polls")
    pollsChanged() {
      const polls = this.polls;
      if (polls) {
        this._polls = this._polls || {};
        polls.forEach(p => {
          const existing = this._polls[p.name];
          if (existing) {
            this._polls[p.name].setProperties(p);
          } else {
            this._polls[p.name] = Ember.Object.create(p);
          }
        });
        this.set("pollsObject", this._polls);
        rerender();
      }
    }
  });

  function attachPolls($elem, helper) {
    const $polls = $(".poll", $elem);
    if (!$polls.length || !helper) {
      return;
    }

    let post = helper.getModel();
    api.preventCloak(post.id);
    post.pollsChanged();

    const polls = post.pollsObject || {};
    const votes = post.polls_votes || {};

    _interval = _interval || setInterval(rerender, 30000);

    $polls.each((idx, pollElem) => {
      const $poll = $(pollElem);
      const pollName = $poll.data("poll-name");
      let poll = polls[pollName];
      let vote = votes[pollName] || [];

      const quotedId = $poll.parent(".expanded-quote").data("post-id");
      if (quotedId) {
        const quotedPost = post.quoted[quotedId];
        if (quotedPost) {
          post = Ember.Object.create(quotedPost);
          poll = Ember.Object.create(
            quotedPost.polls.find(p => p.name === pollName)
          );
          vote = quotedPost.polls_votes || {};
          vote = vote[pollName] || [];
        }
      }

      if (poll) {
        const attrs = {
          id: `${pollName}-${post.id}`,
          post,
          poll,
          vote,
          groupableUserFields: (
            api.container.lookup("site-settings:main")
              .poll_groupable_user_fields || ""
          )
            .split("|")
            .filter(Boolean)
        };
        const glue = new WidgetGlue("discourse-poll", register, attrs);
        glue.appendTo(pollElem);
        _glued.push(glue);
      }
    });
  }

  function cleanUpPolls() {
    if (_interval) {
      clearInterval(_interval);
      _interval = null;
    }

    _glued.forEach(g => g.cleanUp());
    _glued = [];
  }

  api.includePostAttributes("polls", "polls_votes");
  api.decorateCooked(attachPolls, { onlyStream: true, id: "discourse-poll" });
  api.cleanupStream(cleanUpPolls);
}

export default {
  name: "extend-for-poll",

  initialize() {
    withPluginApi("0.8.7", initializePolls);
  }
};
