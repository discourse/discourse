import EmberObject from "@ember/object";
import WidgetGlue from "discourse/widgets/glue";
import { getRegister } from "discourse-common/lib/get-owner";
import { observes } from "discourse-common/utils/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-poll";
let _glued = [];
let _interval = null;

function rerender() {
  _glued.forEach((g) => g.queueRerender());
}

function cleanUpPolls() {
  if (_interval) {
    clearInterval(_interval);
    _interval = null;
  }

  _glued.forEach((g) => g.cleanUp());
  _glued = [];
}

function initializePolls(api) {
  const register = getRegister(api),
    pollGroupableUserFields = api.container.lookup("site-settings:main")
      .poll_groupable_user_fields;
  cleanUpPolls();

  api.modifyClass("controller:topic", {
    pluginId: PLUGIN_ID,
    subscribe() {
      this._super(...arguments);
      this.messageBus.subscribe("/polls/" + this.get("model.id"), (msg) => {
        const post = this.get("model.postStream").findLoadedPost(msg.post_id);
        if (post) {
          post.set("polls", msg.polls);
        }
      });
    },
    unsubscribe() {
      this.messageBus.unsubscribe("/polls/*");
      this._super(...arguments);
    },
  });

  api.modifyClass("model:post", {
    pluginId: PLUGIN_ID,
    _polls: null,
    pollsObject: null,

    // we need a proper ember object so it is bindable
    @observes("polls")
    pollsChanged() {
      const polls = this.polls;
      if (polls) {
        this._polls = this._polls || {};
        polls.forEach((p) => {
          const existing = this._polls[p.name];
          if (existing) {
            this._polls[p.name].setProperties(p);
          } else {
            this._polls[p.name] = EmberObject.create(p);
          }
        });
        this.set("pollsObject", this._polls);
        rerender();
      }
    },
  });

  function attachPolls(elem, helper) {
    const pollNodes = elem.querySelectorAll(".poll");
    if (!pollNodes.length || !helper) {
      return;
    }

    const post = helper.getModel();
    api.preventCloak(post.id);
    post.pollsChanged();

    const polls = post.pollsObject || {};
    const votes = post.polls_votes || {};

    _interval = _interval || setInterval(rerender, 30000);

    pollNodes.forEach((pollNode) => {
      const pollName = pollNode.dataset.pollName;
      let poll = polls[pollName];
      let pollPost = post;
      let vote = votes[pollName] || [];

      const quotedId = pollNode.closest(".expanded-quote")?.dataset.postId;
      if (quotedId && post.quoted[quotedId]) {
        pollPost = post.quoted[quotedId];
        pollPost = EmberObject.create(pollPost);
        poll = EmberObject.create(pollPost.polls.findBy("name", pollName));
        vote = pollPost.polls_votes || {};
        vote = vote[pollName] || [];
      }

      if (poll) {
        const titleElement = pollNode.querySelector(".poll-title");

        const attrs = {
          id: `${pollName}-${pollPost.id}`,
          post: pollPost,
          poll,
          vote,
          hasSavedVote: vote.length > 0,
          titleHTML: titleElement?.outerHTML,
          groupableUserFields: (pollGroupableUserFields || "")
            .split("|")
            .filter(Boolean),
        };
        const glue = new WidgetGlue("discourse-poll", register, attrs);
        glue.appendTo(pollNode);
        _glued.push(glue);
      }
    });
  }

  api.includePostAttributes("polls", "polls_votes");
  api.decorateCookedElement(attachPolls, {
    onlyStream: true,
    id: "discourse-poll",
  });
  api.cleanupStream(cleanUpPolls);
}

export default {
  name: "extend-for-poll",

  initialize() {
    withPluginApi("0.8.7", initializePolls);
  },
};
