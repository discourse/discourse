import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { cancel, next } from "@ember/runloop";
import { cloneJSON } from "discourse-common/lib/object";
import { chatComposerButtons } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import showModal from "discourse/lib/show-modal";
import TextareaInteractor from "discourse/plugins/chat/discourse/lib/textarea-interactor";
import { getOwner } from "discourse-common/lib/get-owner";
import userSearch from "discourse/lib/user-search";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { emojiUrlFor } from "discourse/lib/text";
import { SKIP } from "discourse/lib/autocomplete";
import I18n from "I18n";
import { translations } from "pretty-text/emoji/data";
import { setupHashtagAutocomplete } from "discourse/lib/hashtag-autocomplete";
import { isEmpty, isPresent } from "@ember/utils";

export default class ChatComposer extends Component {
  @service capabilities;
  @service site;
  @service siteSettings;
  @service chat;
  @service chatComposerPresenceManager;
  @service chatComposerWarningsTracker;
  @service appEvents;
  @service chatEmojiReactionStore;
  @service chatEmojiPickerManager;
  @service currentUser;
  @service chatApi;

  @tracked isFocused = false;

  get shouldRenderReplyingIndicator() {
    return this.context === "channel" && !this.args.channel?.isDraft;
  }

  get shouldRenderMessageDetails() {
    return this.currentMessage?.editing || this.currentMessage?.inReplyTo;
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

  get disabled() {
    return (
      (this.args.channel.isDraft &&
        isEmpty(this.args.channel?.chatable?.users)) ||
      !this.chat.userCanInteractWithChat ||
      !this.args.channel.canModifyMessages(this.currentUser)
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
    this.textareaInteractor = new TextareaInteractor(getOwner(this), textarea);
  }

  @action
  didUpdateMessage() {
    cancel(this._persistHandler);
    this.textareaInteractor.value = this.currentMessage.message || "";
    this.textareaInteractor.focus({ refreshHeight: true });
  }

  @action
  didUpdateInReplyTo() {
    this.textareaInteractor.focus({ ensureAtEnd: true, refreshHeight: true });
    this.persistDraft();
  }

  get currentMessage() {
    return this.composer.message;
  }

  get hasContent() {
    const minLength = this.siteSettings.chat_minimum_message_length || 0;
    return (
      this.currentMessage?.message?.length > minLength ||
      (this.canAttachUploads && this.currentMessage?.uploads?.length > 0)
    );
  }

  get sendEnabled() {
    return this.hasContent && !this.pane.sending;
  }

  @action
  setupAppEvents() {
    this.appEvents.on("chat:modify-selection", this, "modifySelection");
    this.appEvents.on(
      "chat:open-insert-link-modal",
      this,
      "openInsertLinkModal"
    );
  }

  @action
  teardownAppEvents() {
    this.appEvents.off("chat:modify-selection", this, "modifySelection");
    this.appEvents.off(
      "chat:open-insert-link-modal",
      this,
      "openInsertLinkModal"
    );
  }

  @action
  insertDiscourseLocalDate() {
    showModal("discourse-local-dates-create-modal").setProperties({
      insertDate: (markup) => {
        this.textareaInteractor.addText(
          this.textareaInteractor.getSelected(),
          markup
        );
        this.textareaInteractor.focus();
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
    this.currentMessage.message = event.target.value;
    this.textareaInteractor.refreshHeight();
    this.reportReplyingPresence();
    this.persistDraft();
    this.captureMentions();
  }

  @action
  onUploadChanged(uploads, { inProgressUploadsCount }) {
    if (
      typeof uploads !== "undefined" &&
      inProgressUploadsCount !== "undefined" &&
      inProgressUploadsCount === 0 &&
      this.currentMessage
    ) {
      this.currentMessage.uploads = cloneJSON(uploads);
    }

    this.textareaInteractor.focus();
    this.reportReplyingPresence();
    this.persistDraft();
  }

  @action
  onSend() {
    if (!this.sendEnabled) {
      return;
    }

    if (this.site.mobileView) {
      // prevents to hide the keyboard after sending a message
      // we use direct DOM manipulation here because textareaInteractor.focus()
      // is using the runloop which is too late
      this.textareaInteractor.textarea.focus();
    }

    this.args.onSendMessage(this.currentMessage);
    this.textareaInteractor.focus({ refreshHeight: true });
  }

  @action
  onCancel() {
    this.composer.cancel();
  }

  reportReplyingPresence() {
    if (this.args.channel.isDraft) {
      return;
    }

    this.chatComposerPresenceManager.notifyState(
      this.args.channel.id,
      !this.currentMessage.editing && this.hasContent
    );
  }

  @action
  modifySelection(event, options = { type: null, context: null }) {
    if (options.context !== this.context) {
      return;
    }

    const sel = this.textareaInteractor.getSelected("", { lineVal: true });
    if (options.type === "bold") {
      this.textareaInteractor.applySurround(sel, "**", "**", "bold_text");
    } else if (options.type === "italic") {
      this.textareaInteractor.applySurround(sel, "_", "_", "italic_text");
    } else if (options.type === "code") {
      this.textareaInteractor.applySurround(sel, "`", "`", "code_text");
    }
  }

  @action
  onTextareaFocusIn(textarea) {
    if (!this.capabilities.isIOS) {
      return;
    }

    // hack to prevent the whole viewport
    // to move on focus input
    textarea = document.querySelector(".chat-composer__input");
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

    if (event.key === "Enter") {
      if (event.shiftKey) {
        // Shift+Enter: insert newline
        return;
      }

      // Ctrl+Enter, plain Enter: send
      if (!event.ctrlKey) {
        // if we are inside a code block just insert newline
        const { pre } = this.textareaInteractor.getSelected({ lineVal: true });
        if (this.textareaInteractor.isInside(pre, /(^|\n)```/g)) {
          return;
        }
      }

      this.onSend();
      event.preventDefault();
      return false;
    }

    if (
      event.key === "ArrowUp" &&
      !this.hasContent &&
      !this.currentMessage.editing
    ) {
      const editableMessage = this.pane?.lastCurrentUserMessage;
      if (editableMessage) {
        this.composer.editMessage(editableMessage);
      }
    }

    if (event.key === "Escape") {
      if (this.currentMessage?.inReplyTo) {
        this.reset();
        return false;
      } else if (this.currentMessage?.editing) {
        this.composer.onCancelEditing();
        return false;
      } else {
        event.target.blur();
      }
    }
  }

  @action
  reset() {
    this.composer.reset(this.args.channel);
  }

  @action
  openInsertLinkModal(event, options = { context: null }) {
    if (options.context !== this.context) {
      return;
    }

    const selected = this.textareaInteractor.getSelected("", { lineVal: true });
    const linkText = selected?.value;
    showModal("insert-hyperlink").setProperties({
      linkText,
      toolbarEvent: {
        addText: (text) => this.textareaInteractor.addText(selected, text),
      },
    });
  }

  @action
  onSelectEmoji(emoji) {
    const code = `:${emoji}:`;
    this.chatEmojiReactionStore.track(code);
    this.textareaInteractor.addText(
      this.textareaInteractor.getSelected(),
      code
    );

    if (this.site.desktopView) {
      this.textareaInteractor.focus();
    } else {
      this.chatEmojiPickerManager.close();
    }
  }

  @action
  captureMentions() {
    if (this.hasContent) {
      this.chatComposerWarningsTracker.trackMentions(
        this.currentMessage.message
      );
    }
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
      transformComplete: (v) => v.username || v.name,
      dataSource: (term) => {
        return userSearch({ term, includeGroups: true }).then((result) => {
          if (result?.users?.length > 0) {
            const presentUserNames =
              this.chat.presenceChannel.users?.mapBy("username");
            result.users.forEach((user) => {
              if (presentUserNames.includes(user.username)) {
                user.cssClasses = "is-online";
              }
            });
          }
          return result;
        });
      },
      afterComplete: (text, event) => {
        event.preventDefault();
        this.textareaInteractor.value = text;
        this.textareaInteractor.focus();
        this.captureMentions();
      },
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
          this.textareaInteractor.value = text;
          this.textareaInteractor.focus();
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
        this.textareaInteractor.value = text;
        this.textareaInteractor.focus();
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
      transformComplete: (v) => {
        if (v.code) {
          this.chatEmojiReactionStore.track(v.code);
          return `${v.code}:`;
        } else {
          $textarea.autocomplete({ cancel: true });
          this.chatEmojiPickerManager.open({
            context: this.context,
            initialFilter: v.term,
          });
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
            if (this.chatEmojiReactionStore.favorites.length) {
              return resolve(this.chatEmojiReactionStore.favorites.slice(0, 5));
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
            diversity: this.chatEmojiReactionStore.diversity,
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
              list.push({ label: I18n.t("composer.more_emoji"), term });
            }
            return list;
          });
      },
    });
  }

  #isAutocompleteDisplayed() {
    return document.querySelector(".autocomplete");
  }
}
