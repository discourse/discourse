import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { withPluginApi } from "discourse/lib/plugin-api";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";

export default {
  name: "chat-keyboard-shortcuts",

  initialize(container) {
    const chatService = container.lookup("service:chat");
    if (!chatService.userCanChat) {
      return;
    }

    const router = container.lookup("service:router");
    const appEvents = container.lookup("service:app-events");
    const modal = container.lookup("service:modal");
    const chatStateManager = container.lookup("service:chat-state-manager");
    const chatThreadPane = container.lookup("service:chat-thread-pane");
    const chatThreadListPane = container.lookup(
      "service:chat-thread-list-pane"
    );
    const chatChannelsManager = container.lookup(
      "service:chat-channels-manager"
    );
    const openQuickChannelSelector = (e) => {
      e.preventDefault();
      e.stopPropagation();
      modal.show(ChatModalNewMessage);
    };

    const handleMoveUpShortcut = (e) => {
      e.preventDefault();
      e.stopPropagation();
      chatService.switchChannelUpOrDown("up");
    };

    const handleMoveDownShortcut = (e) => {
      e.preventDefault();
      e.stopPropagation();
      chatService.switchChannelUpOrDown("down");
    };

    const handleMoveUpUnreadShortcut = (e) => {
      e.preventDefault();
      e.stopPropagation();
      chatService.switchChannelUpOrDown("up", true);
    };

    const handleMoveDownUnreadShortcut = (e) => {
      e.preventDefault();
      e.stopPropagation();
      chatService.switchChannelUpOrDown("down", true);
    };

    const isChatComposer = (el) =>
      el.classList.contains("chat-composer__input");
    const isInputSelection = (el) => {
      const inputs = ["input", "textarea", "select", "button"];
      const elementTagName = el?.tagName.toLowerCase();

      if (inputs.includes(elementTagName)) {
        return false;
      }
      return true;
    };
    const modifyComposerSelection = (event, type) => {
      if (!isChatComposer(event.target)) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
      appEvents.trigger("chat:modify-selection", event, {
        type,
        context: event.target.dataset.chatComposerContext,
      });
    };

    const openInsertLinkModal = (event) => {
      if (!isChatComposer(event.target)) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
      appEvents.trigger("chat:open-insert-link-modal", event, {
        context: event.target.dataset.chatComposerContext,
      });
    };

    const openChatDrawer = (event) => {
      if (!isInputSelection(event.target)) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();

      chatStateManager.prefersDrawer();
      router.transitionTo(chatStateManager.lastKnownChatURL || "chat");
    };

    const closeChat = (event) => {
      // TODO (joffrey): removes this when we move from magnific popup
      // there's no proper way to prevent propagation in mfp
      if (event.srcElement?.classList?.value?.includes("mfp-wrap")) {
        return;
      }

      if (chatStateManager.isDrawerActive) {
        event.preventDefault();
        event.stopPropagation();
        appEvents.trigger("chat:toggle-close", event);
        return;
      }

      if (chatThreadPane.isOpened) {
        event.preventDefault();
        event.stopPropagation();
        chatThreadPane.close();
        return;
      }

      if (chatThreadListPane.isOpened) {
        event.preventDefault();
        event.stopPropagation();
        chatThreadListPane.close();
        return;
      }
    };

    const markAllChannelsRead = (event) => {
      event.preventDefault();
      event.stopPropagation();

      if (chatStateManager.isActive) {
        chatChannelsManager.markAllChannelsRead();
      }
    };

    withPluginApi("0.12.1", (api) => {
      api.addKeyboardShortcut(
        `${PLATFORM_KEY_MODIFIER}+k`,
        openQuickChannelSelector,
        {
          global: true,
          help: {
            category: "chat",
            name: "chat.keyboard_shortcuts.open_quick_channel_selector",
            definition: {
              keys1: ["meta", "k"],
              keysDelimiter: "plus",
            },
          },
        }
      );
      api.addKeyboardShortcut("alt+up", handleMoveUpShortcut, {
        global: true,
        help: {
          category: "chat",
          name: "chat.keyboard_shortcuts.switch_channel_arrows",
          definition: {
            keys1: ["alt", "&uarr;"],
            keys2: ["alt", "&darr;"],
            keysDelimiter: "plus",
            shortcutsDelimiter: "slash",
          },
        },
      });

      api.addKeyboardShortcut("alt+down", handleMoveDownShortcut, {
        global: true,
      });

      api.addKeyboardShortcut("alt+shift+up", handleMoveUpUnreadShortcut, {
        global: true,
        help: {
          category: "chat",
          name: "chat.keyboard_shortcuts.switch__unread_channel_arrows",
          definition: {
            keys1: ["alt", "shift", "&uarr;"],
            keys2: ["alt", "shift", "&darr;"],
            keysDelimiter: "plus",
            shortcutsDelimiter: "newline",
          },
        },
      });

      api.addKeyboardShortcut("alt+shift+down", handleMoveDownUnreadShortcut, {
        global: true,
      });

      api.addKeyboardShortcut(
        `${PLATFORM_KEY_MODIFIER}+b`,
        (event) => modifyComposerSelection(event, "bold"),
        {
          global: true,
          help: {
            category: "chat",
            name: "chat.keyboard_shortcuts.composer_bold",
            definition: {
              keys1: ["meta", "b"],
              keysDelimiter: "plus",
            },
          },
        }
      );
      api.addKeyboardShortcut(
        `${PLATFORM_KEY_MODIFIER}+i`,
        (event) => modifyComposerSelection(event, "italic"),
        {
          global: true,
          help: {
            category: "chat",
            name: "chat.keyboard_shortcuts.composer_italic",
            definition: {
              keys1: ["meta", "i"],
              keysDelimiter: "plus",
            },
          },
        }
      );
      api.addKeyboardShortcut(
        `${PLATFORM_KEY_MODIFIER}+e`,
        (event) => modifyComposerSelection(event, "code"),
        {
          global: true,
          help: {
            category: "chat",
            name: "chat.keyboard_shortcuts.composer_code",
            definition: {
              keys1: ["meta", "e"],
              keysDelimiter: "plus",
            },
          },
        }
      );
      api.addKeyboardShortcut(
        `${PLATFORM_KEY_MODIFIER}+l`,
        (event) => openInsertLinkModal(event),
        {
          global: true,
          help: {
            category: "chat",
            name: "chat.keyboard_shortcuts.open_insert_link_modal",
            definition: {
              keys1: ["meta", "l"],
              keysDelimiter: "plus",
            },
          },
        }
      );
      api.addKeyboardShortcut(`-`, (event) => openChatDrawer(event), {
        global: true,
        help: {
          category: "chat",
          name: "chat.keyboard_shortcuts.drawer_open",
          definition: {
            keys1: ["-"],
          },
        },
      });
      api.addKeyboardShortcut("esc", (event) => closeChat(event), {
        global: true,
        help: {
          category: "chat",
          name: "chat.keyboard_shortcuts.drawer_close",
          definition: {
            keys1: ["esc"],
          },
        },
      });
      api.addKeyboardShortcut(
        `shift+esc`,
        (event) => markAllChannelsRead(event),
        {
          global: true,
          help: {
            category: "chat",
            name: "chat.keyboard_shortcuts.mark_all_channels_read",
            definition: {
              keys1: ["shift", "esc"],
              keysDelimiter: "plus",
            },
          },
        }
      );
    });
  },
};
