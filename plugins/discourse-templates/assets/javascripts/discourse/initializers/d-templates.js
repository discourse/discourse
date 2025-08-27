import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { withPluginApi } from "discourse/lib/plugin-api";
import extractVariablesFromChatChannel from "../../lib/variables-chat-channel";
import extractVariablesFromChatThread from "../../lib/variables-chat-thread";

export default {
  name: "discourse-templates-add-ui-builder",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");

    if (
      siteSettings.discourse_templates_enabled &&
      currentUser?.can_use_templates
    ) {
      withPluginApi((api) => {
        addOptionsMenuItem(api);
        addKeyboardShortcut(api, container);
        addChatIntegration(api, container);
      });
    }
  },
};

function addOptionsMenuItem(api) {
  const dTemplates = api.container.lookup("service:d-templates");

  api.addComposerToolbarPopupMenuOption({
    icon: "far-clipboard",
    label: "templates.insert_template",
    action: () => {
      dTemplates.showComposerUI();
    },
  });
}

const _templateShortcutTargets = [];

function addKeyboardShortcut(api, container) {
  api.addKeyboardShortcut(
    `${PLATFORM_KEY_MODIFIER}+shift+i`,
    (event) => {
      event.preventDefault();
      const dTemplates = container.lookup("service:d-templates");

      if (dTemplates.isComposerFocused) {
        dTemplates.showComposerUI();
        return;
      }

      for (const target of _templateShortcutTargets) {
        if (
          dTemplates.isTextAreaFocused &&
          target?.isFocused?.(document.activeElement)
        ) {
          dTemplates.showTextAreaUI(target?.variables);
          return;
        }
      }

      if (dTemplates.isTextAreaFocused) {
        dTemplates.showTextAreaUI();
      }
    },
    {
      global: true,
      help: {
        category: "templates",
        name: "templates.insert_template",
        definition: {
          keys1: [PLATFORM_KEY_MODIFIER, "shift", "i"],
          keysDelimiter: "plus",
        },
      },
    }
  );
}

function addChatIntegration(api, container) {
  if (!container.lookup("service:chat")?.userCanChat) {
    return;
  }

  const channelVariablesExtractor = function () {
    const chat = container.lookup("service:chat");
    const activeChannel = chat?.activeChannel;
    const currentMessage = activeChannel?.draft;
    const router = container.lookup("service:router");

    return extractVariablesFromChatChannel(
      activeChannel,
      currentMessage,
      router
    );
  };

  const threadVariablesExtractor = function () {
    const chat = container.lookup("service:chat");
    const activeThread = chat?.activeChannel?.activeThread;
    const currentMessage = activeThread?.draft;
    const router = container.lookup("service:router");

    return extractVariablesFromChatThread(activeThread, currentMessage, router);
  };

  // add a custom chat composer button
  api.registerChatComposerButton({
    id: "d-templates-chat-insert-template-btn",
    icon: "far-clipboard",
    label: "templates.insert_template",
    position: "dropdown",
    action: function () {
      let contextVariablesExtractor;
      switch (this.context) {
        case "channel":
          contextVariablesExtractor = channelVariablesExtractor.bind(this);
          break;
        case "thread":
          contextVariablesExtractor = threadVariablesExtractor.bind(this);
          break;
        default:
          contextVariablesExtractor = null;
      }

      const textarea = this.composer?.textarea?.textarea; // this.composer.textarea is a TextareaInteractor instance

      container
        .lookup("service:d-templates")
        .showTextAreaUI(contextVariablesExtractor, textarea);
    },
    displayed() {
      return (
        this.composer?.textarea &&
        (this.context === "channel" || this.context === "thread")
      );
    },
  });

  // add custom keyboard shortcut handlers for the chat channel composer and chat thread composer
  _templateShortcutTargets.push(
    {
      isFocused: (element) => element?.id === "channel-composer",
      variables: channelVariablesExtractor,
    },
    {
      isFocused: (element) => element?.id === "thread-composer",
      variables: threadVariablesExtractor,
    }
  );
}
