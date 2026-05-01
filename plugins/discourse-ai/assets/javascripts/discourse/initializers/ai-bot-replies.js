import { withPluginApi } from "discourse/lib/plugin-api";
import AiBotDockedComposer from "../components/ai-bot-docked-composer";
import AiBotHeaderIcon from "../components/ai-bot-header-icon";
import AiAgentFlair from "../components/post/ai-agent-flair";
import AiCancelStreaming from "../components/post/meta-data/ai-cancel-streaming";
import AiCancelStreamingButton from "../components/post-menu/ai-cancel-streaming-button";
import AiDebugButton from "../components/post-menu/ai-debug-button";
import AiRetryStreamingButton from "../components/post-menu/ai-retry-streaming-button";
import AiShareButton from "../components/post-menu/ai-share-button";
import { isGPTBot, showShareConversationModal } from "../lib/ai-bot-helper";
import {
  cleanupStreamingData,
  streamPostText,
} from "../lib/ai-streamer/progress-handlers";

function focusDockedComposer() {
  requestAnimationFrame(() => {
    document.querySelector(".ai-bot-docked-composer .d-editor-input")?.focus();
  });
}

function lookupStreamingState(api) {
  // Guarded because the container may be destroyed by the time the
  // topic controller's unsubscribe hook runs (particularly during
  // test tear-down of acceptance suites).
  try {
    return api.container.lookup("service:ai-bot-streaming-state");
  } catch {
    return null;
  }
}

let allowDebug = false;

function attachHeaderIcon(api) {
  api.headerIcons.add("ai", AiBotHeaderIcon);
}

function initializeAIBotReplies(api) {
  initializePauseButton(api);

  api.renderInOutlet("topic-area-bottom", AiBotDockedComposer);

  // Suppress MoreTopics tabs (Related Messages / Suggested) entirely on
  // bot PMs. Relying on CSS `display: none` on `.more-topics__container`
  // was racey during back-to-forum navigation: the body class could lag
  // the DOM teardown and leave the tabs briefly visible on the next
  // route. Returning an empty tabs array instead keeps the component
  // rendering nothing regardless of transition timing.
  api.registerValueTransformer("more-topics-tabs", ({ value, context }) => {
    if (context?.topic?.is_bot_pm) {
      return [];
    }
    return value;
  });

  api.modifyClass("controller:topic", {
    pluginId: "discourse-ai",

    onAIBotStreamedReply: function (data) {
      if (!this.model?.postStream) {
        return;
      }

      const streamingState = lookupStreamingState(api);
      const topicId = this.model.id;

      if (data?.done) {
        streamingState?.markFinishedAfterRender(topicId, data?.post_id);
      } else {
        const postId = data?.post_id;
        // If the post is already rendered and has no .streaming class, this
        // chunk is a stale replay of a stream that already finished. Calling
        // markStarted would wrongly show the stop button until the 15-s idle
        // timer fires. Clear any leftover state and bail out instead.
        if (postId) {
          const postEl = document.querySelector(`[data-post-id="${postId}"]`);
          if (postEl && !postEl.classList.contains("streaming")) {
            streamingState?.markFinished(topicId);
            return;
          }
        }
        streamingState?.markStarted(topicId, postId);
      }

      streamPostText(this.model.postStream, data);
    },
    subscribe: function () {
      this._super();

      if (
        this.model.isPrivateMessage &&
        this.model.details.allowed_users &&
        this.model.details.allowed_users.filter(isGPTBot).length >= 1
      ) {
        // -2 replays only the last message before listening for new ones.
        // A completed stream always ends with done:true as its final message,
        // so replaying just the last event is enough to resume an in-progress
        // stream AND avoids the stale-state bug where replaying an earlier
        // chunk calls markStarted right before the done message, leaving the
        // MutationObserver waiting for a .streaming class that never gets
        // removed (because streamPostText has nothing left to stream).
        this.messageBus.subscribe(
          `discourse-ai/ai-bot/topic/${this.model.id}`,
          this.onAIBotStreamedReply.bind(this),
          -2
        );
      }
    },
    unsubscribe: function () {
      // we may have infected post stream so lets clean it up
      if (this.model?.postStream) {
        cleanupStreamingData(this.model.postStream);
      }

      if (this.model?.id) {
        // Guarded lookup: the container can be destroyed before
        // `unsubscribe` runs (teardown during test owner destruction),
        // in which case there's nothing to mark finished anyway.
        const streamingState = lookupStreamingState(api);
        streamingState?.markFinished(this.model.id);
      }

      this.messageBus.unsubscribe("discourse-ai/ai-bot/topic/*");
      this._super();
    },
  });

  // When a user triggers a reply on a bot PM (via the `r` shortcut, the
  // reply button, or a quote), focus the docked composer. The floating
  // composer still opens internally but is hidden by CSS; quote text it
  // receives is relayed to the docked composer via `composer:insert-block`
  // which our DEditor subscribes to.
  api.onAppEvent("page:compose-reply", (topic) => {
    if (topic?.is_bot_pm) {
      focusDockedComposer();
    }
  });
}

function initializeAgentDecorator(api) {
  api.renderAfterWrapperOutlet("post-meta-data-poster-name", AiAgentFlair);
}

function initializePauseButton(api) {
  // Add cancel streaming button to post-menu (bottom of post) - hidden by CSS, kept for compatibility
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, firstButtonKey } }) => {
      if (isGPTBot(post.user)) {
        dag.add("ai-cancel-gpt", AiCancelStreamingButton, {
          before: firstButtonKey,
          after: ["ai-share", "ai-debug"],
        });
      }
    }
  );

  // Add cancel streaming to post-infos (top of post, where date is shown)
  api.registerValueTransformer(
    "post-meta-data-infos",
    ({ value: dag, context: { post, metaDataInfoKeys } }) => {
      if (isGPTBot(post.user)) {
        dag.add("ai-cancel-streaming", AiCancelStreaming, {
          before: metaDataInfoKeys.DATE,
        });
      }
    }
  );
}

function initializeRetryButton(api) {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, firstButtonKey } }) => {
      if (isGPTBot(post.user)) {
        dag.add("ai-retry", AiRetryStreamingButton, {
          before: firstButtonKey,
          after: ["ai-cancel-gpt", "ai-share", "ai-debug"],
        });
      }
    }
  );
}

function initializeDebugButton(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.ai_enabled_chat_bots || !allowDebug) {
    return;
  }

  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, firstButtonKey } }) => {
      if (post.topic?.archetype === "private_message") {
        dag.add("ai-debug", AiDebugButton, {
          before: firstButtonKey,
          after: "ai-share",
        });
      }
    }
  );
}

function initializeShareButton(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.ai_enabled_chat_bots) {
    return;
  }

  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, firstButtonKey } }) => {
      if (post.topic?.archetype === "private_message") {
        dag.add("ai-share", AiShareButton, {
          before: firstButtonKey,
        });
      }
    }
  );
}

function initializeShareTopicButton(api) {
  const modal = api.container.lookup("service:modal");
  const currentUser = api.container.lookup("service:current-user");

  api.registerTopicFooterButton({
    id: "share-ai-conversation",
    icon: "share-nodes",
    label: "discourse_ai.ai_bot.share_ai_conversation.name",
    title: "discourse_ai.ai_bot.share_ai_conversation.title",
    action() {
      showShareConversationModal(modal, this.topic.id);
    },
    classNames: ["share-ai-conversation-button"],
    dependentKeys: ["topic.ai_agent_name"],
    displayed() {
      return (
        currentUser?.can_share_ai_bot_conversations && this.topic.ai_agent_name
      );
    },
  });
}

export default {
  name: "discourse-ai-bot-replies",

  initialize(container) {
    const user = container.lookup("service:current-user");

    if (user?.ai_enabled_chat_bots) {
      allowDebug = user.can_debug_ai_bot_conversations;

      withPluginApi((api) => {
        attachHeaderIcon(api);
        initializeAIBotReplies(api);
        initializeAgentDecorator(api);
        initializeDebugButton(api, container);
        initializeShareButton(api, container);
        initializeShareTopicButton(api, container);
        initializeRetryButton(api);
      });
    }
  },
};
