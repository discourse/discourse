import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import $ from "jquery";
import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";
import { Promise } from "rsvp";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import InsertHyperlink from "discourse/components/modal/insert-hyperlink";
import { SKIP } from "discourse/lib/autocomplete";
import { setupHashtagAutocomplete } from "discourse/lib/hashtag-autocomplete";
import { emojiUrlFor } from "discourse/lib/text";
import userSearch from "discourse/lib/user-search";
import {
  destroyUserStatuses,
  initUserStatusHtml,
  renderUserStatusHtml,
} from "discourse/lib/user-status-on-autocomplete";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";
import { waitForClosedKeyboard } from "discourse/lib/wait-for-keyboard";
import { cloneJSON } from "discourse-common/lib/object";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { i18n } from "discourse-i18n";
import { chatComposerButtons } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import TextareaInteractor from "discourse/plugins/chat/discourse/lib/textarea-interactor";

const CHAT_PRESENCE_KEEP_ALIVE = 5 * 1000; // 5 seconds

export default class ChatComposer extends Component {
  @service capabilities;
  @service site;
  @service siteSettings;
  @service store;
  @service chat;
  @service composerPresenceManager;
  @service chatComposerWarningsTracker;
  @service appEvents;
  @service emojiStore;
  @service currentUser;
  @service chatApi;
  @service chatDraftsManager;
  @service modal;
  @service menu;

  @tracked isFocused = false;
  @tracked inProgressUploadsCount = 0;
  @tracked presenceChannelName;

  get shouldRenderMessageDetails() {
    return (
      this.draft?.editing ||
      (this.context === "channel" && this.draft?.inReplyTo)
    );
  }

  get inlineButtons() {
    return chatComposerButtons(this, "inline", this.context);
  }

  get dropdownButtons() {
    return chatComposerButtons(this, "dropdown", this.context);
  }

  get fileUploadElementId() {
    return this.context + "-file-uploader";
  }

  get canAttachUploads() {
    return (
      this.siteSettings.chat_allow_uploads &&
      isPresent(this.args.uploadDropZone)
    );
  }

  @action
  persistDraft() {}

  @action
  setupAutocomplete(textarea) {
    const $textarea = $(textarea);
    this.#applyUserAutocomplete($textarea);
    this.#applyEmojiAutocomplete($textarea);
    this.#applyCategoryHashtagAutocomplete($textarea);
  }

  @action
  setupTextareaInteractor(textarea) {
    this.composer.textarea = new TextareaInteractor(getOwner(this), textarea);

    if (this.site.desktopView && this.args.autofocus) {
      this.composer.focus({ ensureAtEnd: true, refreshHeight: true });
    }
  }

  @action
  didUpdateMessage() {
    this.cancelPersistDraft();
    this.composer.textarea.value = this.draft.message;
    this.persistDraft();
    this.captureMentions({ skipDebounce: true });
  }

  @action
  didUpdateInReplyTo() {
    this.cancelPersistDraft();
    this.persistDraft();
  }

  @action
  cancelPersistDraft() {
    cancel(this._persistHandler);
  }

  @action
  handleInlineButtonAction(buttonAction, event) {
    event.stopPropagation();

    buttonAction();
  }

  get hasContent() {
    const minLength = this.siteSettings.chat_minimum_message_length || 1;
    return (
      this.draft?.message?.length >= minLength ||
      (this.canAttachUploads && this.hasUploads)
    );
  }

  get hasUploads() {
    return this.draft?.uploads?.length > 0;
  }

  get sendEnabled() {
    return (
      (this.hasContent || this.draft?.editing) &&
      !this.pane.sending &&
      !this.inProgressUploadsCount > 0
    );
  }

  @action
  setup() {
    this.composer.scroller = this.args.scroller;
    this.appEvents.on("chat:modify-selection", this, "modifySelection");
    this.appEvents.on(
      "chat:open-insert-link-modal",
      this,
      "openInsertLinkModal"
    );
  }

  @action
  teardown() {
    this.appEvents.off("chat:modify-selection", this, "modifySelection");
    this.appEvents.off(
      "chat:open-insert-link-modal",
      this,
      "openInsertLinkModal"
    );
    this.pane.sending = false;
  }

  @action
  insertDiscourseLocalDate() {
    // JIT import because local-dates isn't necessarily enabled
    const LocalDatesCreateModal =
      require("discourse/plugins/discourse-local-dates/discourse/components/modal/local-dates-create").default;

    this.modal.show(LocalDatesCreateModal, {
      model: {
        insertDate: (markup) => {
          this.composer.textarea.addText(
            this.composer.textarea.getSelected(),
            markup
          );
          this.composer.focus();
        },
      },
    });
  }

  @action
  uploadClicked() {
    document.querySelector(`#${this.fileUploadElementId}`).click();
  }

  @action
  computeIsFocused(isFocused) {
    next(() => {
      this.isFocused = isFocused;
    });
  }

  @action
  onInput(event) {
    this.draft.draftSaved = false;
    this.draft.message = event.target.value;
    this.composer.textarea.refreshHeight();
    this.reportReplyingPresence();
    this.persistDraft();
    this.captureMentions();
  }

  @action
  onUploadChanged(uploads, { inProgressUploadsCount }) {
    this.draft.draftSaved = false;

    this.inProgressUploadsCount = inProgressUploadsCount || 0;

    if (
      typeof uploads !== "undefined" &&
      inProgressUploadsCount !== "undefined" &&
      inProgressUploadsCount === 0 &&
      this.draft
    ) {
      this.draft.uploads = cloneJSON(uploads);
    }

    this.composer.textarea?.focus();
    this.reportReplyingPresence();
    this.persistDraft();
  }

  @action
  trapMouseDown(event) {
    event?.preventDefault();
  }

  @action
  async onSend(event) {
    if (!this.sendEnabled) {
      return;
    }

    event?.preventDefault();

    if (
      this.draft.editing &&
      !this.hasUploads &&
      this.draft.message.length === 0
    ) {
      this.#deleteEmptyMessage();
      return;
    }

    await this.args.onSendMessage(this.draft);
    this.composer.textarea.refreshHeight();
  }

  reportReplyingPresence() {
    if (!this.args.channel || !this.draft) {
      return;
    }

    this.composerPresenceManager.notifyState(
      this.presenceChannelName,
      !this.draft.editing && this.hasContent,
      CHAT_PRESENCE_KEEP_ALIVE
    );
  }

  @action
  modifySelection(event, options = { type: null, context: null }) {
    if (options.context !== this.context) {
      return;
    }

    const sel = this.composer.textarea.getSelected("", { lineVal: true });
    if (options.type === "bold") {
      this.composer.textarea.applySurround(sel, "**", "**", "bold_text");
    } else if (options.type === "italic") {
      this.composer.textarea.applySurround(sel, "_", "_", "italic_text");
    } else if (options.type === "code") {
      this.composer.textarea.applySurround(sel, "`", "`", "code_text");
    }
  }

  @action
  onTextareaFocusOut() {
    this.isFocused = false;
  }

  @action
  onTextareaFocusIn(event) {
    this.isFocused = true;

    if (!this.capabilities.isIOS) {
      return;
    }

    // hack to prevent the whole viewport to move on focus input
    const textarea = event.target;
    textarea.style.transform = "translateY(-99999px)";
    textarea.focus();
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        textarea.style.transform = "";
      });
    });
  }

  @action
  onKeyDown(event) {
    if (
      this.site.mobileView ||
      event.altKey ||
      event.metaKey ||
      this.#isAutocompleteDisplayed()
    ) {
      return;
    }

    if (event.key === "Escape" && !event.shiftKey) {
      return this.handleEscape(event);
    }

    if (event.key === "Enter") {
      if (event.shiftKey) {
        // Shift+Enter: insert newline
        return;
      }

      // Ctrl+Enter, plain Enter: send
      if (!event.ctrlKey) {
        // if we are inside a code block just insert newline
        const { pre } = this.composer.textarea.getSelected({ lineVal: true });
        if (this.composer.textarea.isInside(pre, /(^|\n)```/g)) {
          return;
        }
      }

      this.onSend();
      event.preventDefault();
      return false;
    }

    if (event.key === "ArrowUp" && !this.hasContent && !this.draft.editing) {
      if (event.shiftKey && this.lastMessage?.replyable) {
        this.composer.replyTo(this.lastMessage);
      } else {
        const editableMessage = this.lastUserMessage(this.currentUser);
        if (editableMessage?.editable) {
          this.composer.edit(editableMessage);
          this.args.channel.draft = editableMessage;
        }
      }
    }
  }

  @action
  openInsertLinkModal(event, options = { context: null }) {
    if (options.context !== this.context) {
      return;
    }

    const selected = this.composer.textarea.getSelected("", { lineVal: true });
    const linkText = selected?.value;
    this.modal.show(InsertHyperlink, {
      model: {
        linkText,
        toolbarEvent: {
          addText: (text) => this.composer.textarea.addText(selected, text),
        },
      },
    });
  }

  @action
  onSelectEmoji(emoji) {
    this.composer.textarea.emojiSelected(emoji);

    if (this.site.desktopView) {
      this.composer.focus();
    }
  }

  @action
  captureMentions(opts = { skipDebounce: false }) {
    if (this.hasContent) {
      this.chatComposerWarningsTracker.trackMentions(
        this.draft,
        opts.skipDebounce
      );
    } else {
      this.chatComposerWarningsTracker.reset();
    }
  }

  #addMentionedUser(userData) {
    const user = this.store.createRecord("user", userData);
    this.draft.mentionedUsers.set(user.id, user);
  }

  #applyUserAutocomplete($textarea) {
    if (!this.siteSettings.enable_mentions) {
      return;
    }

    $textarea.autocomplete({
      template: findRawTemplate("user-selector-autocomplete"),
      key: "@",
      width: "100%",
      treatAsTextarea: true,
      autoSelectFirstSuggestion: true,
      transformComplete: (obj) => {
        if (obj.isUser) {
          this.#addMentionedUser(obj);
        }

        return obj.username || obj.name;
      },
      dataSource: (term) => {
        destroyUserStatuses();
        return userSearch({ term, includeGroups: true }).then((result) => {
          if (result?.users?.length > 0) {
            const presentUserNames =
              this.chat.presenceChannel.users?.mapBy("username");
            result.users.forEach((user) => {
              if (presentUserNames.includes(user.username)) {
                user.cssClasses = "is-online";
              }
            });
            initUserStatusHtml(getOwner(this), result.users);
          }
          return result;
        });
      },
      onRender: (options) => {
        renderUserStatusHtml(options);
      },
      afterComplete: (text, event) => {
        event.preventDefault();
        this.composer.textarea.value = text;
        this.composer.focus();
        this.captureMentions();
      },
      onClose: destroyUserStatuses,
    });
  }

  #applyCategoryHashtagAutocomplete($textarea) {
    setupHashtagAutocomplete(
      this.site.hashtag_configurations["chat-composer"],
      $textarea,
      this.siteSettings,
      {
        treatAsTextarea: true,
        afterComplete: (text, event) => {
          event.preventDefault();
          this.composer.textarea.value = text;
          this.composer.focus();
        },
      }
    );
  }

  #applyEmojiAutocomplete($textarea) {
    if (!this.siteSettings.enable_emoji) {
      return;
    }

    $textarea.autocomplete({
      template: findRawTemplate("emoji-selector-autocomplete"),
      key: ":",
      afterComplete: (text, event) => {
        event.preventDefault();
        this.composer.textarea.value = text;
        this.composer.focus();
      },
      treatAsTextarea: true,
      onKeyUp: (text, cp) => {
        const matches =
          /(?:^|[\s.\?,@\/#!%&*;:\[\]{}=\-_()])(:(?!:).?[\w-]*:?(?!:)(?:t\d?)?:?) ?$/gi.exec(
            text.substring(0, cp)
          );

        if (matches && matches[1]) {
          return [matches[1]];
        }
      },
      transformComplete: async (v) => {
        if (v.code) {
          return `${v.code}:`;
        } else {
          $textarea.autocomplete({ cancel: true });

          const menuOptions = {
            identifier: "emoji-picker",
            groupIdentifier: "emoji-picker",
            component: EmojiPickerDetached,
            context: `channel_${this.args.channel.id}`,
            modalForMobile: true,
            data: {
              didSelectEmoji: (emoji) => {
                this.onSelectEmoji(emoji);
              },
              term: v.term,
              context: "chat",
            },
          };

          // Close the keyboard before showing the emoji picker
          // it avoids a whole range of bugs on iOS
          await waitForClosedKeyboard(this);

          const virtualElement = virtualElementFromTextRange();
          this.menuInstance = await this.menu.show(virtualElement, menuOptions);
          return "";
        }
      },
      dataSource: (term) => {
        return new Promise((resolve) => {
          const full = `:${term}`;
          term = term.toLowerCase();

          // We need to avoid quick emoji autocomplete cause it can interfere with quick
          // typing, set minimal length to 2
          let minLength = Math.max(
            this.siteSettings.emoji_autocomplete_min_chars,
            2
          );

          if (term.length < minLength) {
            return resolve(SKIP);
          }

          // bypass :-p and other common typed smileys
          if (
            !term.match(
              /[^-\{\}\[\]\(\)\*_\<\>\\\/].*[^-\{\}\[\]\(\)\*_\<\>\\\/]/
            )
          ) {
            return resolve(SKIP);
          }

          if (term === "") {
            const favorites = this.emojiStore.favoritesForContext("chat");
            if (favorites.length > 0) {
              return resolve(favorites.slice(0, 5));
            } else {
              return resolve([
                "slight_smile",
                "smile",
                "wink",
                "sunny",
                "blush",
              ]);
            }
          }

          // note this will only work for emojis starting with :
          // eg: :-)
          const emojiTranslation = this.site.custom_emoji_translation || {};
          const allTranslations = Object.assign(
            {},
            translations,
            emojiTranslation
          );
          if (allTranslations[full]) {
            return resolve([allTranslations[full]]);
          }

          const emojiDenied = this.site.denied_emojis || [];
          const match = term.match(/^:?(.*?):t([2-6])?$/);
          if (match) {
            const name = match[1];
            const scale = match[2];

            if (isSkinTonableEmoji(name) && !emojiDenied.includes(name)) {
              if (scale) {
                return resolve([`${name}:t${scale}`]);
              } else {
                return resolve([2, 3, 4, 5, 6].map((x) => `${name}:t${x}`));
              }
            }
          }

          const options = emojiSearch(term, {
            maxResults: 5,
            diversity: this.emojiStore.diversity,
            exclude: emojiDenied,
          });

          return resolve(options);
        })
          .then((list) => {
            if (list === SKIP) {
              return;
            }
            return list.map((code) => ({ code, src: emojiUrlFor(code) }));
          })
          .then((list) => {
            if (list?.length) {
              list.push({ label: i18n("composer.more_emoji"), term });
            }
            return list;
          });
      },
    });
  }

  #isAutocompleteDisplayed() {
    return document.querySelector(".autocomplete");
  }

  #deleteEmptyMessage() {
    new ChatMessageInteractor(
      getOwner(this),
      this.draft,
      this.context
    ).delete();
    this.resetDraft();
  }
}
