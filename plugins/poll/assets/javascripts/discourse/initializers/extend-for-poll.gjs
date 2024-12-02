import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { TrackedObject } from "tracked-built-ins";
import { withPluginApi } from "discourse/lib/plugin-api";
import { bind } from "discourse-common/utils/decorators";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";
import Poll from "../components/poll";

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
      poll = new TrackedObject(pollPost.polls.find((p) => p.name === pollName));
    }

    if (poll) {
      const titleHTML = pollNode.querySelector(".poll-title")?.outerHTML;

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
      helper.renderGlimmer(newPollNode, <template>
        <Poll @poll={{poll}} @post={{post}} @titleHTML={{titleHTML}} />
      </template>);
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
        _onPollMessage(msg) {
          const post = this.get("model.postStream").findLoadedPost(msg.post_id);
          if (post) {
            post.polls = msg.polls;
          }
        }
      }
  );

  api.modifyClass(
    "model:post",
    (Superclass) =>
      class extends Superclass {
        @tracked pollsObject = new TrackedObject();
        @tracked _polls;

        get polls() {
          return this._polls;
        }

        set polls(value) {
          this._polls = value;
          this._refreshPollsObject();
        }

        _refreshPollsObject() {
          for (const rawPoll of this.polls) {
            const name = rawPoll.name;
            this.pollsObject[name] ||= new TrackedObject();
            Object.assign(this.pollsObject[name], rawPoll);
          }
        }
      }
  );

  api.decorateCookedElement(attachPolls, { onlyStream: true });

  const siteSettings = api.container.lookup("service:site-settings");
  if (siteSettings.poll_enabled) {
    api.addSearchSuggestion("in:polls");
  }
}

export default {
  name: "extend-for-poll",

  initialize() {
    withPluginApi("0.8.7", initializePolls);
  },
};
