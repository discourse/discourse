import { hbs } from "ember-cli-htmlbars";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
import AiBotHeaderIcon from "../discourse/components/ai-bot-header-icon";
import AiPersonaFlair from "../discourse/components/post/ai-persona-flair";
import AiCancelStreamingButton from "../discourse/components/post-menu/ai-cancel-streaming-button";
import AiDebugButton from "../discourse/components/post-menu/ai-debug-button";
import AiShareButton from "../discourse/components/post-menu/ai-share-button";
import {
  getBotType,
  isGPTBot,
  showShareConversationModal,
} from "../discourse/lib/ai-bot-helper";
import { streamPostText } from "../discourse/lib/ai-streamer/progress-handlers";

let allowDebug = false;

function attachHeaderIcon(api) {
  api.headerIcons.add("ai", AiBotHeaderIcon);
}

function initializeAIBotReplies(api) {
  initializePauseButton(api);

  api.modifyClass("controller:topic", {
    pluginId: "discourse-ai",

    onAIBotStreamedReply: function (data) {
      streamPostText(this.model.postStream, data);
    },
    subscribe: function () {
      this._super();

      if (
        this.model.isPrivateMessage &&
        this.model.details.allowed_users &&
        this.model.details.allowed_users.filter(isGPTBot).length >= 1
      ) {
        // we attempt to recover the last message in the bus
        // so we subscribe at -2
        this.messageBus.subscribe(
          `discourse-ai/ai-bot/topic/${this.model.id}`,
          this.onAIBotStreamedReply.bind(this),
          -2
        );
      }
    },
    unsubscribe: function () {
      this.messageBus.unsubscribe("discourse-ai/ai-bot/topic/*");
      this._super();
    },
  });
}

function initializePersonaDecorator(api) {
  api.renderAfterWrapperOutlet("post-meta-data-poster-name", AiPersonaFlair);

  withSilencedDeprecations("discourse.post-stream-widget-overrides", () =>
    initializeWidgetPersonaDecorator(api)
  );
}

function initializeWidgetPersonaDecorator(api) {
  api.decorateWidget(`poster-name:after`, (dec) => {
    const botType = getBotType(dec.attrs.user);
    // we have 2 ways of decorating
    // 1. if a bot is a LLM we decorate with persona name
    // 2. if bot is a persona we decorate with LLM name
    if (botType === "llm") {
      return dec.widget.attach("persona-flair", {
        personaName: dec.model?.topic?.ai_persona_name,
      });
    } else if (botType === "persona") {
      return dec.widget.attach("persona-flair", {
        personaName: dec.model?.llm_name,
      });
    }
  });

  registerWidgetShim(
    "persona-flair",
    "span.persona-flair",
    hbs`{{@data.personaName}}`
  );
}

function initializePauseButton(api) {
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
    dependentKeys: ["topic.ai_persona_name"],
    displayed() {
      return (
        currentUser?.can_share_ai_bot_conversations &&
        this.topic.ai_persona_name
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
        initializePersonaDecorator(api);
        initializeDebugButton(api, container);
        initializeShareButton(api, container);
        initializeShareTopicButton(api, container);
      });
    }
  },
};
