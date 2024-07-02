import { withPluginApi } from "discourse/lib/plugin-api";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { replaceIcon } from "discourse-common/lib/icon-library";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import { MENTION_KEYWORDS } from "discourse/plugins/chat/discourse/components/chat-message";
import { clearChatComposerButtons } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import ChannelHashtagType from "discourse/plugins/chat/discourse/lib/hashtag-types/channel";
import ChatHeaderIcon from "../components/chat/header/icon";
import chatStyleguide from "../components/styleguide/organisms/chat";

let _lastForcedRefreshAt;
const MIN_REFRESH_DURATION_MS = 180000; // 3 minutes

replaceIcon("d-chat", "comment");

export default {
  name: "chat-setup",
  before: "hashtag-css-generator",

  initialize(container) {
    this.router = container.lookup("service:router");
    this.chatService = container.lookup("service:chat");
    this.chatHistory = container.lookup("service:chat-history");
    this.site = container.lookup("service:site");
    this.siteSettings = container.lookup("service:site-settings");
    this.currentUser = container.lookup("service:current-user");
    this.appEvents = container.lookup("service:app-events");
    this.appEvents.on("discourse:focus-changed", this, "_handleFocusChanged");

    if (!this.chatService.userCanChat) {
      return;
    }

    withPluginApi("0.12.1", (api) => {
      api.onPageChange((path) => {
        const route = this.router.recognize(path);
        if (route.name.startsWith("chat.")) {
          this.chatHistory.visit(route);
        }
      });

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
        icon: "far-smile",
        position: this.site.desktopView ? "inline" : "dropdown",
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
      api.decorateCookedElement((elem) => {
        const currentUser = getOwnerWithFallback(this).lookup(
          "service:current-user"
        );
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
      });

      if (!this.chatService.userCanChat) {
        return;
      }

      document.body.classList.add("chat-enabled");

      this.chatService.loadChannels();

      const chatNotificationManager = container.lookup(
        "service:chat-notification-manager"
      );
      chatNotificationManager.start();

      if (!this._registeredDocumentTitleCountCallback) {
        api.addDocumentTitleCounter(this.documentTitleCountCallback);
        this._registeredDocumentTitleCountCallback = true;
      }

      api.addCardClickListenerSelector(".chat-drawer-outlet");

      if (this.chatService.userCanChat) {
        api.headerIcons.add("chat", ChatHeaderIcon);
      }

      api.addStyleguideSection?.({
        component: chatStyleguide,
        category: "organisms",
        id: "chat",
      });

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
        if (chatChannel.allowChannelWideMentions) {
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
