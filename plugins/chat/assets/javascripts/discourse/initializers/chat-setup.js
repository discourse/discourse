import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import { number } from "discourse/lib/formatter";
import { withPluginApi } from "discourse/lib/plugin-api";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { replaceIcon } from "discourse-common/lib/icon-library";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import { clearChatComposerButtons } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import ChannelHashtagType from "discourse/plugins/chat/discourse/lib/hashtag-types/channel";
import ChatHeaderIcon from "../components/chat/header/icon";
import chatStyleguide from "../components/styleguide/organisms/chat";

let _lastForcedRefreshAt;
const MIN_REFRESH_DURATION_MS = 180000; // 3 minutes

replaceIcon("d-chat", "comment");

class ChatSetupInit {
  @service router;
  @service("chat") chatService;
  @service chatHistory;
  @service site;
  @service siteSettings;
  @service currentUser;
  @service appEvents;

  constructor(owner) {
    setOwner(this, owner);
    this.appEvents.on("discourse:focus-changed", this, "_handleFocusChanged");

    withPluginApi("0.12.1", (api) => {
      api.addAboutPageActivity("chat_messages", (periods) => {
        const count = periods["7_days"];
        if (count) {
          return {
            icon: "comment-dots",
            class: "chat-messages",
            activityText: i18n("about.activities.chat_messages", {
              count,
              formatted_number: number(count),
            }),
            period: i18n("about.activities.periods.last_7_days"),
          };
        }
      });

      if (!this.chatService.userCanChat) {
        return;
      }

      api.onPageChange((path) => {
        const route = this.router.recognize(path);
        if (route.name.startsWith("chat.")) {
          this.chatHistory.visit(route);
        }
      });

      api.registerHashtagType("channel", new ChannelHashtagType(owner));

      if (this.siteSettings.enable_emoji) {
        api.registerChatComposerButton({
          label: "chat.emoji",
          id: "emoji",
          class: "chat-emoji-btn",
          icon: "discourse-emojis",
          position: "dropdown",
          displayed: owner.lookup("service:site").mobileView,
          action(context) {
            const didSelectEmoji = (emoji) => {
              const composer = owner.lookup(`service:chat-${context}-composer`);
              composer.textarea.addText(
                composer.textarea.getSelected(),
                `:${emoji}:`
              );
            };

            owner.lookup("service:menu").show(document.body, {
              identifier: "emoji-picker",
              groupIdentifier: "emoji-picker",
              component: EmojiPickerDetached,
              modalForMobile: true,
              data: {
                context: "chat",
                didSelectEmoji,
              },
            });
          },
        });
      }

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
          icon: "calendar-days",
          position: "dropdown",
          action() {
            this.insertDiscourseLocalDate();
          },
        });
      }

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
              .format(i18n("dates.long_no_year"));
          } else {
            dateTimeEl.innerText = moment(dateTimeRaw).format(
              i18n("dates.long_no_year")
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

      const chatNotificationManager = owner.lookup(
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
    });
  }

  @bind
  documentTitleCountCallback() {
    return this.chatService.getDocumentTitleCount();
  }

  teardown() {
    this.appEvents.off("discourse:focus-changed", this, "_handleFocusChanged");

    if (!this.chatService.userCanChat) {
      return;
    }

    _lastForcedRefreshAt = null;
    clearChatComposerButtons();
  }

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
  }
}

export default {
  name: "chat-setup",
  before: "hashtag-css-generator",
  initialize(owner) {
    this.instance = new ChatSetupInit(owner);
  },
  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
