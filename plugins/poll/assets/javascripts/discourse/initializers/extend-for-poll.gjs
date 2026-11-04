import EmberObject from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder.gjs";
import Poll from "../components/poll.gjs";

function attachPolls(elem, helper) {
  let pollNodes = [...elem.querySelectorAll(".poll")];
  pollNodes = pollNodes.filter(
    (node) => node.parentNode.tagName !== "BLOCKQUOTE"
  );
  if (!pollNodes.length || !helper) {
    return;
  }

  const post = helper.getModel();
  const polls = post.pollsObject;

  pollNodes.forEach((pollNode) => {
    const pollName = pollNode.dataset.pollName;
    let poll = polls[pollName];
    let pollPost = post;

    const quotedId = pollNode.closest(".expanded-quote")?.dataset.postId;

    if (quotedId && post.quoted[quotedId]) {
      pollPost = EmberObject.create(post.quoted[quotedId]);
      poll = trackedObject(pollPost.polls.find((p) => p.name === pollName));
    }

    if (poll) {
      const titleHTML = pollNode.querySelector(".poll-title")?.outerHTML;
      const isDynamic = pollNode.dataset.pollDynamic === "true";

      const newPollNode = document.createElement("div");
      Object.assign(newPollNode.dataset, {
        pollName: poll.name,
        pollType: poll.type,
      });
      newPollNode.classList.add("poll-outer");
      if (poll.chart_type === PIE_CHART_TYPE) {
        newPollNode.classList.add("pie");
      }

      pollNode.replaceWith(newPollNode);
      helper.renderGlimmer(
        newPollNode,
        <template>
          <Poll
            @isDynamic={{if isDynamic true poll.dynamic}}
            @poll={{poll}}
            @post={{pollPost}}
            @titleHTML={{titleHTML}}
          />
        </template>
      );
    }
  });
}

function initializePolls(api) {
  api.modifyClass(
    "controller:topic",
    (Superclass) =>
      class extends Superclass {
        subscribe() {
          super.subscribe(...arguments);
          this.messageBus.subscribe(
            `/polls/${this.model.id}`,
            this._onPollMessage
          );
        }

        unsubscribe() {
          this.messageBus.unsubscribe("/polls/*", this._onPollMessage);
          super.unsubscribe(...arguments);
        }

        @bind
        async _onPollMessage(msg) {
          const postStream = this.get("model.postStream");
          const post = postStream.findLoadedPost(msg.post_id);
          if (!post) {
            return;
          }

          const refreshes = (this._pollRefreshes ||= new WeakMap());
          if (refreshes.has(post)) {
            refreshes.set(post, true);
            return;
          }

          try {
            do {
              refreshes.set(post, false);
              // Fetch with current permissions instead of trusting retained content.
              const refreshed = await ajax(`/posts/${post.id}.json`);
              if (
                this.isDestroying ||
                this.isDestroyed ||
                this.get("model.postStream") !== postStream ||
                postStream.findLoadedPost(post.id) !== post
              ) {
                return;
              }
              post.polls = refreshed.polls || [];
            } while (refreshes.get(post));
          } catch {
            // The post may have been hidden, deleted, or made inaccessible.
          } finally {
            refreshes.delete(post);
          }
        }
      }
  );

  api.addModelField("post", "polls_votes", { type: "object" });
  api.addModelField("post", "pollsObject", { type: "object" });
  api.addModelField("post", "_polls");

  api.addModelAccessor("post", "polls", {
    get() {
      return this._polls;
    },
    set(value) {
      this._polls = value;
      this._refreshPollsObject();
    },
  });

  api.addModelMethod("post", "_refreshPollsObject", function () {
    for (const rawPoll of this.polls) {
      const name = rawPoll.name;
      this.pollsObject[name] ||= trackedObject();
      Object.assign(this.pollsObject[name], rawPoll);
    }
  });

  api.decorateCookedElement(attachPolls, { onlyStream: true });

  const siteSettings = api.container.lookup("service:site-settings");
  if (siteSettings.poll_enabled) {
    api.addSearchSuggestion("in:polls");
  }
}

export default {
  name: "extend-for-poll",

  initialize() {
    withPluginApi(initializePolls);
  },
};
