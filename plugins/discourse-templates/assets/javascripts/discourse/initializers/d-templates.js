import { withPluginApi } from "discourse/lib/plugin-api";
import { PLATFORM_KEY_MODIFIER } from "discourse/services/keyboard-shortcuts";
import extractVariablesFromChatChannel from "../../lib/variables-chat-channel.js";
import extractVariablesFromChatThread from "../../lib/variables-chat-thread.js";

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
        const editor = target.editor();
        if (editor && editor.element === document.activeElement) {
          dTemplates.showEditorUI(editor, target.variables);
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

      container
        .lookup("service:d-templates")
        .showEditorUI(this.composer.editor, contextVariablesExtractor);
    },
    displayed() {
      return (
        this.composer?.editor &&
        (this.context === "channel" || this.context === "thread")
      );
    },
  });

  // add custom keyboard shortcut handlers for the chat channel composer and chat thread composer
  _templateShortcutTargets.push(
    {
      editor: () => container.lookup("service:chat-channel-composer").editor,
      variables: channelVariablesExtractor,
    },
    {
      editor: () => container.lookup("service:chat-thread-composer").editor,
      variables: threadVariablesExtractor,
    }
  );
}
