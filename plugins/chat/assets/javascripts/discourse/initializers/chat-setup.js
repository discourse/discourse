import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "I18n";
import { bind } from "discourse-common/utils/decorators";
import { getOwner } from "discourse-common/lib/get-owner";
import { MENTION_KEYWORDS } from "discourse/plugins/chat/discourse/components/chat-message";
import { clearChatComposerButtons } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import ChannelHashtagType from "discourse/plugins/chat/discourse/lib/hashtag-types/channel";
import { replaceIcon } from "discourse-common/lib/icon-library";

let _lastForcedRefreshAt;
const MIN_REFRESH_DURATION_MS = 180000; // 3 minutes

replaceIcon("d-chat", "comment");

export default {
  name: "chat-setup",
  before: "hashtag-css-generator",

  initialize(container) {
    this.chatService = container.lookup("service:chat");
    this.siteSettings = container.lookup("service:site-settings");
    this.appEvents = container.lookup("service:appEvents");
    this.appEvents.on("discourse:focus-changed", this, "_handleFocusChanged");

    if (!this.chatService.userCanChat) {
      return;
    }

    withPluginApi("0.12.1", (api) => {
      api.registerHashtagType("channel", new ChannelHashtagType(container));

      api.registerChatComposerButton({
        id: "chat-upload-btn",
        icon: "far-image",
        label: "chat.upload",
        position: "dropdown",
        action: "uploadClicked",
        dependentKeys: ["canAttachUploads"],
        displayed() {
          return this.canAttachUploads;
        },
      });

      if (this.siteSettings.discourse_local_dates_enabled) {
        api.registerChatComposerButton({
          label: "discourse_local_dates.title",
          id: "local-dates",
          class: "chat-local-dates-btn",
          icon: "calendar-alt",
          position: "dropdown",
          action() {
            this.insertDiscourseLocalDate();
          },
        });
      }

      api.registerChatComposerButton({
        label: "chat.emoji",
        id: "emoji",
        class: "chat-emoji-btn",
        icon: "discourse-emojis",
        position: "dropdown",
        context: "channel",
        action() {
          const chatEmojiPickerManager = container.lookup(
            "service:chat-emoji-picker-manager"
          );
          chatEmojiPickerManager.open({ context: "channel" });
        },
      });

      api.registerChatComposerButton({
        label: "chat.emoji",
        id: "channel-emoji",
        class: "chat-emoji-btn",
        icon: "discourse-emojis",
        position: "dropdown",
        context: "thread",
        action() {
          const chatEmojiPickerManager = container.lookup(
            "service:chat-emoji-picker-manager"
          );
          chatEmojiPickerManager.open({ context: "thread" });
        },
      });

      // we want to decorate the chat quote dates regardless
      // of whether the current user has chat enabled
      api.decorateCookedElement(
        (elem) => {
          const currentUser = getOwner(this).lookup("service:current-user");
          const currentUserTimezone = currentUser?.user_option?.timezone;
          const chatTranscriptElements =
            elem.querySelectorAll(".chat-transcript");

          chatTranscriptElements.forEach((el) => {
            const dateTimeRaw = el.dataset["datetime"];
            const dateTimeEl = el.querySelector(
              ".chat-transcript-datetime a, .chat-transcript-datetime span"
            );

            if (currentUserTimezone) {
              dateTimeEl.innerText = moment
                .tz(dateTimeRaw, currentUserTimezone)
                .format(I18n.t("dates.long_no_year"));
            } else {
              dateTimeEl.innerText = moment(dateTimeRaw).format(
                I18n.t("dates.long_no_year")
              );
            }

            dateTimeEl.dataset.dateFormatted = true;
          });
        },
        { id: "chat-transcript-datetime" }
      );

      if (!this.chatService.userCanChat) {
        return;
      }

      document.body.classList.add("chat-enabled");

      const currentUser = api.getCurrentUser();
      if (currentUser?.chat_channels) {
        this.chatService.setupWithPreloadedChannels(currentUser.chat_channels);
      }

      const chatNotificationManager = container.lookup(
        "service:chat-notification-manager"
      );
      chatNotificationManager.start();

      if (!this._registeredDocumentTitleCountCallback) {
        api.addDocumentTitleCounter(this.documentTitleCountCallback);
        this._registeredDocumentTitleCountCallback = true;
      }

      api.addCardClickListenerSelector(".chat-drawer-outlet");

      api.addToHeaderIcons("chat-header-icon");

      api.addChatDrawerStateCallback(({ isDrawerActive }) => {
        if (isDrawerActive) {
          document.body.classList.add("chat-drawer-active");
        } else {
          document.body.classList.remove("chat-drawer-active");
        }
      });

      api.decorateChatMessage(function (chatMessage, chatChannel) {
        if (!this.currentUser) {
          return;
        }

        const highlightable = [`@${this.currentUser.username}`];
        if (chatChannel.allow_channel_wide_mentions) {
          highlightable.push(...MENTION_KEYWORDS.map((k) => `@${k}`));
        }

        chatMessage.querySelectorAll(".mention").forEach((node) => {
          const mention = node.textContent.trim();
          if (highlightable.includes(mention)) {
            node.classList.add("highlighted", "valid-mention");
          }
        });
      });
    });
  },

  @bind
  documentTitleCountCallback() {
    return this.chatService.getDocumentTitleCount();
  },

  teardown() {
    this.appEvents.off("discourse:focus-changed", this, "_handleFocusChanged");

    if (!this.chatService.userCanChat) {
      return;
    }

    _lastForcedRefreshAt = null;
    clearChatComposerButtons();
  },

  @bind
  _handleFocusChanged(hasFocus) {
    if (!this.chatService.userCanChat) {
      return;
    }

    if (!hasFocus) {
      _lastForcedRefreshAt = Date.now();
      return;
    }

    _lastForcedRefreshAt = _lastForcedRefreshAt || Date.now();

    const duration = Date.now() - _lastForcedRefreshAt;
    if (duration <= MIN_REFRESH_DURATION_MS) {
      return;
    }

    _lastForcedRefreshAt = Date.now();
  },
};
