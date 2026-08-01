import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import ComposerPickerDetached from "discourse/components/composer-picker/detached";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import GifsModal from "discourse/components/modal/gifs";
import { bind } from "discourse/lib/decorators";
import EmbedMode from "discourse/lib/embed-mode";
import { number } from "discourse/lib/formatter";
import { replaceIcon } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { clearChatComposerButtons } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import {
  buildChatPickerSelectHandler,
  buildGifPickHandler,
} from "discourse/plugins/chat/discourse/lib/gif-pick-handler";
import ChannelHashtagType from "discourse/plugins/chat/discourse/lib/hashtag-types/channel";
import richEditorExtension from "../../lib/rich-editor-extension";
import ChatHeaderIcon from "../components/chat/header/icon";
import chatStyleguide from "../components/styleguide/organisms/chat";

let _lastForcedRefreshAt;
const MIN_REFRESH_DURATION_MS = 180000; // 3 minutes

replaceIcon("d-chat", "comment");

class ChatSetupInit {
  @service router;
  @service("chat") chatService;
  @service chatHistory;
  @service siteSettings;
  @service appEvents;

  constructor(owner) {
    setOwner(this, owner);
    this.appEvents.on("discourse:focus-changed", this, "_handleFocusChanged");

    withPluginApi((api) => {
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
        // include chat elements for anons (except header icon)
        if (
          this.chatService.anonymousUserCanViewPublicChat &&
          !EmbedMode.enabled
        ) {
          document.body.classList.add("chat-enabled");
          api.addCardClickListenerSelector(".chat-drawer-outlet");
        }

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
          icon: "face-smile",
          position: "dropdown",
          displayed: () => owner.lookup("service:site").mobileView,
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
        synchronous: true,
        dependentKeys: ["canAttachUploads"],
        displayed() {
          return this.canAttachUploads;
        },
      });

      if (this.siteSettings.enable_gifs) {
        if (this.siteSettings.enable_unified_composer_picker) {
          api.registerChatComposerButton({
            id: "gifs",
            label: "gifs.composer_title",
            icon: "gif",
            position: "dropdown",
            // On desktop the picker has an inline trigger; the dropdown entry
            // is only needed on mobile, where it opens the same tabbed picker
            // (on the GIFs tab) as a full-screen modal.
            displayed() {
              return this.site.mobileView;
            },
            action(context) {
              const menu = owner.lookup("service:menu");
              const currentUser = owner.lookup("service:current-user");
              const target = document.querySelector(
                `[data-chat-composer-context="${context}"]`
              );

              menu.show(target, {
                identifier: "composer-picker",
                groupIdentifier: "composer-picker",
                component: ComposerPickerDetached,
                modalForMobile: true,
                data: {
                  context: "chat",
                  initialTab: "gifs",
                  onSelect: buildChatPickerSelectHandler({
                    api,
                    composer: this,
                    currentUser,
                  }),
                },
              });
            },
          });
        } else {
          api.registerChatComposerButton({
            id: "gifs",
            label: "gifs.composer_title",
            icon: "gif",
            position: "dropdown",
            action(context) {
              const modal = owner.lookup("service:modal");
              const currentUser = owner.lookup("service:current-user");

              modal.show(GifsModal, {
                model: {
                  customPickHandler: buildGifPickHandler({
                    api,
                    draft: this.draft,
                    isThread: context === "thread",
                    currentUser,
                  }),
                },
              });
            },
          });
        }
      }

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
        const currentUser = owner.lookup("service:current-user");
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

      if (!this.chatService.userCanChat || EmbedMode.enabled) {
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
        api.headerIcons.add("chat", ChatHeaderIcon, {
          after: "search",
          before: "hamburger",
        });
      }

      api.addStyleguideSection?.({
        component: chatStyleguide,
        category: "organisms",
        id: "chat",
      });

      api.registerRichEditorExtension(richEditorExtension);
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
