import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import { normalizeEmoji } from "pretty-text/emoji";
import { replacements } from "pretty-text/emoji/data";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import UpsertHyperlink from "discourse/components/modal/upsert-hyperlink";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import {
  emojiAutocompleteOptions,
  mentionAutocompleteOptions,
} from "discourse/lib/composer/autocomplete-options";
import {
  setCompositionMode,
  toggledCompositionMode,
} from "discourse/lib/composer/composition-mode";
import { getExtensions } from "discourse/lib/composer/rich-editor-extensions";
import selectionToolbarExtension from "discourse/lib/composer/selection-toolbar-extension";
import { SEND_SHORTCUT_META_ENTER } from "discourse/lib/constants";
import { hashtagAutocompleteOptions } from "discourse/lib/hashtag-autocomplete";
import KeyValueStore from "discourse/lib/key-value-store";
import loadRichEditor from "discourse/lib/load-rich-editor";
import { cloneJSON } from "discourse/lib/object";
import optionalService from "discourse/lib/optional-service";
import { TextareaAutocompleteHandler } from "discourse/lib/textarea-text-manipulation";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";
import { waitForClosedKeyboard } from "discourse/lib/wait-for-keyboard";
import forceScrollingElementPosition from "discourse/modifiers/force-scrolling-element-position";
import preventScrollOnFocus from "discourse/modifiers/prevent-scroll-on-focus";
import { and, not, or } from "discourse/truth-helpers";
import DTextarea from "discourse/ui-kit/d-textarea";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dAutocomplete from "discourse/ui-kit/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import DButton from "discourse/plugins/chat/discourse/components/chat/composer/button";
import ChatComposerDropdown from "discourse/plugins/chat/discourse/components/chat-composer-dropdown";
import ChatComposerMessageDetails from "discourse/plugins/chat/discourse/components/chat-composer-message-details";
import ChatComposerUploads from "discourse/plugins/chat/discourse/components/chat-composer-uploads";
import ChatReplyingIndicator from "discourse/plugins/chat/discourse/components/chat-replying-indicator";
import { chatComposerButtons } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import ChatFormattingToolbar, {
  SELECTION_TOOLBAR_BUTTONS,
} from "discourse/plugins/chat/discourse/lib/chat-formatting-toolbar";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import RichEditorInteractor from "discourse/plugins/chat/discourse/lib/rich-editor-interactor";
import TextareaInteractor from "discourse/plugins/chat/discourse/lib/textarea-interactor";
import LocalDatesCreateModal from "discourse/plugins/discourse-local-dates/discourse/components/modal/local-dates-create" with {
  discourseImport: "optional",
};

const CHAT_PRESENCE_KEEP_ALIVE = 5 * 1000; // 5 seconds

const store = new KeyValueStore("discourse_chat_composer_");

export default class ChatComposer extends Component {
  @service site;
  @service siteSettings;
  @service capabilities;
  @service store;
  @service chat;
  @service chatComposerWarningsTracker;
  @service appEvents;
  @service emojiStore;
  @service currentUser;
  @service modal;
  @service menu;

  @optionalService composerPresenceManager;

  @tracked isFocused = false;
  @tracked inProgressUploadsCount = 0;
  @tracked richEditorComponent;
  @tracked showFormattingBar = !!store.getObject("formatting_bar");

  formattingToolbar = this.#buildToolbar();
  richEditorExtensions;

  #textareaInteractor;

  constructor() {
    super(...arguments);

    if (this.useRichEditor) {
      this.composer.awaitEditor();
      this.#loadRichEditor();
    }
  }

  get useRichEditor() {
    return !!this.currentUser?.useRichEditor;
  }

  get editor() {
    return this.composer.editor;
  }

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

  get disabled() {
    return !this.currentUser || this.args.disabled;
  }

  // A handler returning false consumes the key; true lets the editor apply
  // its own binding.
  get richEditorKeymap() {
    const skip = () =>
      this.capabilities.isMobileDevice || this.#isAutocompleteDisplayed();
    const send = () => {
      if (skip()) {
        return true;
      }
      this.onSend();
      return false;
    };

    return {
      // Inside lists, code blocks and the like Enter keeps its structural
      // meaning (new item, new line); only a plain paragraph sends.
      Enter: () => {
        if (this.#isAutocompleteDisplayed() || !this.#inPlainParagraph()) {
          return true;
        }

        if (!this.capabilities.isMobileDevice && this.#sendsOnEnter(false)) {
          this.onSend();
          return false;
        }

        this.#insertLineBreak();
        return false;
      },
      "Mod+Enter": send,
      "Ctrl+Enter": send,
      "Ctrl+m": () => {
        this.toggleEditor();
        return false;
      },
      ArrowUp: () => skip() || !this.#editOrReplyToLastMessage(false),
      "Shift+ArrowUp": () => skip() || !this.#editOrReplyToLastMessage(true),
    };
  }

  @action
  persistDraft() {}

  @action
  setupAutocomplete(textarea) {
    const autocompleteHandler = new TextareaAutocompleteHandler(textarea);
    const apply = (options) =>
      dAutocomplete.setupAutocomplete(
        getOwner(this),
        textarea,
        autocompleteHandler,
        {
          ...options,
          treatAsTextarea: true,
          afterComplete: (text, event) => {
            event.preventDefault();
            this.editor.syncValue(text);
            options.afterComplete?.();
          },
        }
      );

    this.#applyAutocompletes(apply);
  }

  @action
  setupTextareaInteractor(textarea) {
    this.#textareaInteractor = new TextareaInteractor(getOwner(this), textarea);
    this.composer.registerEditor(this.#textareaInteractor);
    this.#autofocus();
  }

  @action
  teardownTextareaInteractor() {
    this.composer.unregisterEditor(this.#textareaInteractor);
    this.#textareaInteractor.destroy();
    this.#textareaInteractor = null;
  }

  @action
  setupRichEditor(textManipulation) {
    const interactor = new RichEditorInteractor(
      getOwner(this),
      textManipulation
    );
    // chat's keyboard shortcuts route by this attribute, as on the textarea
    interactor.element.dataset.chatComposerContext = this.context;
    interactor.element.addEventListener("keydown", this.onRichEditorKeyDown);
    this.composer.registerEditor(interactor);

    this.#applyAutocompletes((options) =>
      textManipulation.autocomplete({
        ...options,
        triggerRule: async () => !(await textManipulation.inCodeBlock()),
      })
    );

    this.#autofocus();

    return () => {
      textManipulation.autocomplete("destroy");
      interactor.element.removeEventListener(
        "keydown",
        this.onRichEditorKeyDown
      );
      this.composer.unregisterEditor(interactor);
    };
  }

  @action
  async toggleEditor() {
    const preference = toggledCompositionMode(this.currentUser);

    if (!this.useRichEditor) {
      this.composer.awaitEditor();
      await this.#loadRichEditor();
    }

    // Removing a focused editor mid-render would flip isFocused during the
    // same render that reads it.
    this.editor?.element.blur();

    setCompositionMode(this.currentUser, preference);

    next(() => this.composer.focus({ ensureAtEnd: true }));
  }

  @action
  toggleFormattingBar() {
    this.showFormattingBar = !this.showFormattingBar;
    store.setObject({ key: "formatting_bar", value: this.showFormattingBar });
  }

  @action
  didUpdateMessage() {
    this.cancelPersistDraft();
    this.editor?.syncValue(this.draft.message);
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

  @action
  focusOrPromptLogin(event) {
    if (!this.currentUser) {
      this.showLogin();
      return;
    }

    // clicks inside the editor focus it on their own, and stealing focus
    // from its controls closes them
    if (event.target.closest(".chat-composer__input")) {
      return;
    }

    this.composer.focus();
  }

  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  setup() {
    this.composer.scroller = this.args.scroller;
    this.appEvents.on("chat:modify-selection", this, "modifySelection");
    this.appEvents.on(
      "chat:open-insert-link-modal",
      this,
      "openUpsertLinkModal"
    );
  }

  @action
  teardown() {
    this.composer.stopAwaitingEditor();
    this.appEvents.off("chat:modify-selection", this, "modifySelection");
    this.appEvents.off(
      "chat:open-insert-link-modal",
      this,
      "openUpsertLinkModal"
    );
    this.pane.sending = false;
  }

  @action
  insertDiscourseLocalDate() {
    this.modal.show(LocalDatesCreateModal, {
      model: {
        insertDate: (markup) => {
          this.editor.addText(this.editor.getSelected(), markup);
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
    this.editor.refreshHeight();
    this.reportReplyingPresence();
    this.persistDraft();
    this.captureMentions();
  }

  @action
  onUploadChanged(uploads, { inProgressUploadsCount }) {
    this.draft.draftSaved = false;

    this.inProgressUploadsCount = inProgressUploadsCount || 0;

    this.editor?.focus();
    this.reportReplyingPresence();

    // Only persist once uploads settle.
    if (
      typeof uploads !== "undefined" &&
      inProgressUploadsCount === 0 &&
      this.draft
    ) {
      this.draft.uploads = cloneJSON(uploads);
      this.persistDraft();
    }
  }

  @action
  trapMouseDown(event) {
    event?.preventDefault();
  }

  @action
  async onSend(event) {
    if (!this.currentUser) {
      this.showLogin();
      return;
    }

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

    if (await this.reactingToLastMessage()) {
      return;
    }

    await this.args.onSendMessage(this.draft);
    this.editor.refreshHeight();
  }

  async reactingToLastMessage() {
    if (!this.siteSettings.enable_emoji) {
      return false;
    }

    // Check if the message is a reaction to the latest message in the channel.
    const message = this.draft.message.trim();
    let reactionCode = "";
    if (message.startsWith("+")) {
      const reaction = message.substring(1);
      // First check if the message is +{emoji}
      if (replacements[reaction]) {
        reactionCode = replacements[reaction];
      } else {
        // Then check if the message is +:{emoji_code}:
        const emojiCode = reaction.substring(1, reaction.length - 1);
        reactionCode = normalizeEmoji(emojiCode);
      }
    }

    if (reactionCode && this.lastMessage?.id) {
      const interactor = new ChatMessageInteractor(
        getOwner(this),
        this.lastMessage,
        this.context
      );

      await interactor.react(reactionCode, "add");
      this.resetDraft();
      return true;
    }

    return false;
  }

  reportReplyingPresence() {
    if (!this.args.channel || !this.draft) {
      return;
    }

    this.composerPresenceManager?.notifyState(
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

    const sel = this.editor.getSelected("", { lineVal: true });
    if (options.type === "bold") {
      this.editor.applySurround(sel, "**", "**", "bold_text");
    } else if (options.type === "italic") {
      this.editor.applySurround(sel, "_", "_", "italic_text");
    } else if (options.type === "code") {
      this.editor.applySurround(sel, "`", "`", "code_text");
    }
  }

  forceScrollPosition() {
    if (!this.capabilities.isIOS || this.capabilities.isIpadOS) {
      return;
    }

    // attempts to reposition body
    if (window.pageYOffset <= 100) {
      // on iOS scrolling to 0 doesn’t work correctly
      // scrolling to -1 is more consistent
      window.scrollTo(0, -1);
    }
  }

  @action
  onTextareaFocusOut() {
    this.forceScrollPosition();
    this.isFocused = false;
  }

  @action
  onTextareaFocusIn() {
    if (!this.currentUser) {
      this.showLogin();
      return;
    }

    this.forceScrollPosition();
    this.isFocused = true;
  }

  // Escape needs the DOM event: subclasses stop it from reaching the global
  // shortcut that closes the drawer or thread.
  @action
  onRichEditorKeyDown(event) {
    if (
      event.key === "Escape" &&
      !event.shiftKey &&
      !this.capabilities.isMobileDevice &&
      !this.#isAutocompleteDisplayed()
    ) {
      this.handleEscape(event);
    }
  }

  @action
  onKeyDown(event) {
    if (
      this.capabilities.isMobileDevice ||
      event.altKey ||
      event.isComposing ||
      this.#isAutocompleteDisplayed()
    ) {
      return;
    }

    if (event.key === "Escape" && !event.shiftKey) {
      return this.handleEscape(event);
    }

    if (event.key === "m" && event.ctrlKey) {
      event.preventDefault();
      this.toggleEditor();
      return;
    }

    if (event.key === "Enter") {
      const send =
        this.#sendsOnEnter(event.shiftKey) || event.ctrlKey || event.metaKey;

      if (!send) {
        // insert newline
        return;
      }

      this.onSend();
      event.preventDefault();
      return false;
    }

    if (event.key === "ArrowUp") {
      this.#editOrReplyToLastMessage(event.shiftKey);
    }
  }

  @action
  openUpsertLinkModal(event, options = { context: null }) {
    if (options.context !== this.context) {
      return;
    }

    const selected = this.editor.getSelected("", { lineVal: true });
    const hasSelection = !!selected && selected.start !== selected.end;
    this.modal.show(UpsertHyperlink, {
      model: {
        hasSelection,
        toolbarEvent: {
          selected,
          addText: (text) => this.editor.addText(selected, text),
          applyLink: (url) => this.editor.applyLink(url),
        },
      },
    });
  }

  @action
  onSelectEmoji(emoji, context = null) {
    this.editor.insertEmoji(emoji, context);

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

  async #loadRichEditor() {
    if (this.richEditorComponent) {
      return;
    }

    const component = await loadRichEditor();

    // read after the load, which registers the default extensions; touch
    // devices keep their native selection menu
    if (!this.capabilities.touch) {
      const selectionToolbar = this.#buildToolbar(SELECTION_TOOLBAR_BUTTONS);
      this.richEditorExtensions = [
        ...getExtensions(),
        // the formatting bar already offers the same buttons
        selectionToolbarExtension(() =>
          this.showFormattingBar ? null : selectionToolbar
        ),
      ];
    }

    this.richEditorComponent = component;
  }

  #buildToolbar(only) {
    return new ChatFormattingToolbar({
      siteSettings: this.siteSettings,
      capabilities: this.capabilities,
      site: this.site,
      only,
      getEditor: () => this.editor,
      openLinkModal: () =>
        this.openUpsertLinkModal(null, { context: this.context }),
    });
  }

  #autofocus() {
    if (this.site.desktopView && this.args.autofocus) {
      next(() =>
        this.composer.focus({ ensureAtEnd: true, refreshHeight: true })
      );
    }
  }

  #inPlainParagraph() {
    const { view } = this.editor.textManipulation;
    const { $from } = view.state.selection;

    return (
      $from.depth === 1 &&
      $from.parent.type === view.state.schema.nodes.paragraph
    );
  }

  // Matches the markdown editor's newline rather than starting a paragraph.
  #insertLineBreak() {
    const { view } = this.editor.textManipulation;

    view.dispatch(
      view.state.tr
        .replaceSelectionWith(view.state.schema.nodes.hard_break.create())
        .scrollIntoView()
    );
  }

  #sendsOnEnter(shiftKey) {
    return (
      this.currentUser.user_option.send_shortcut !== SEND_SHORTCUT_META_ENTER &&
      !shiftKey
    );
  }

  #editOrReplyToLastMessage(reply) {
    if (this.hasContent || this.draft.editing) {
      return false;
    }

    if (reply && this.lastMessage?.replyable) {
      this.composer.replyTo(this.lastMessage);
      return true;
    }

    const editableMessage = this.lastUserMessage(this.currentUser);
    if (!editableMessage?.editable) {
      return false;
    }

    this.composer.edit(editableMessage);
    this.args.channel.draft = editableMessage;
    return true;
  }

  #addMentionedUser(userData) {
    const user = this.store.createRecord("user", userData);
    this.draft.mentionedUsers.set(user.id, user);
  }

  #applyAutocompletes(apply) {
    if (this.siteSettings.enable_mentions) {
      apply(this.#userAutocompleteOptions());
    }

    if (this.siteSettings.enable_emoji) {
      apply(this.#emojiAutocompleteOptions());
    }

    apply(
      hashtagAutocompleteOptions(
        this.site.hashtag_configurations["chat-composer"],
        {
          fixedTextareaPosition: true,
          afterComplete: () => this.composer.focus(),
        }
      )
    );
  }

  #userAutocompleteOptions() {
    return {
      ...mentionAutocompleteOptions({
        owner: getOwner(this),
        decorateUsers: (users) => {
          const present = this.chat.presenceChannel.users?.map(
            (user) => user.username
          );
          users.forEach((user) => {
            if (present?.includes(user.username)) {
              user.cssClasses = "is-online";
            }
          });
        },
        onSelect: (result) => {
          if (result.isUser) {
            this.#addMentionedUser(cloneJSON(result));
          }
        },
      }),
      width: "100%",
      fixedTextareaPosition: true,
      autoSelectFirstSuggestion: true,
      afterComplete: () => {
        this.composer.focus();
        this.captureMentions();
      },
    };
  }

  #emojiAutocompleteOptions() {
    return {
      ...emojiAutocompleteOptions({
        site: this.site,
        siteSettings: this.siteSettings,
        emojiStore: this.emojiStore,
        context: "chat",
        openPicker: (term) => this.#openEmojiPicker(term),
        // quick typing shouldn't trip the autocomplete
        minLength: 2,
        ignoreEmoticons: true,
      }),
      fixedTextareaPosition: true,
      afterComplete: () => this.composer.focus(),
    };
  }

  async #openEmojiPicker(term) {
    const emojiContext = this.editor.emojiTermContext();

    // Close the keyboard before showing the emoji picker
    // it avoids a whole range of bugs on iOS
    await waitForClosedKeyboard(this.site, this.capabilities);

    this.menuInstance = await this.menu.show(virtualElementFromTextRange(), {
      identifier: "emoji-picker",
      groupIdentifier: "emoji-picker",
      component: EmojiPickerDetached,
      context: "chat",
      modalForMobile: true,
      data: {
        didSelectEmoji: (emoji) => this.onSelectEmoji(emoji, emojiContext),
        term,
        context: "chat",
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

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    {{! eslint-disable ember/template-no-invalid-interactive }}

    <div class="chat-composer__wrapper">
      {{#if this.shouldRenderMessageDetails}}
        <ChatComposerMessageDetails
          @cancelAction={{this.resetDraft}}
          @message={{if this.draft.editing this.draft this.draft.inReplyTo}}
        />
      {{/if}}

      <div
        aria-label={{i18n "chat.aria_roles.composer"}}
        class={{dConcatClass
          "chat-composer"
          (if this.isFocused "is-focused")
          (if this.pane.sending "is-sending")
          (if this.sendEnabled "is-send-enabled" "is-send-disabled")
          (if this.disabled "is-disabled" "is-enabled")
          (if this.draft.draftSaved "is-draft-saved" "is-draft-unsaved")
        }}
        role="region"
        {{didUpdate this.didUpdateMessage this.draft}}
        {{didUpdate this.didUpdateInReplyTo this.draft.inReplyTo}}
        {{didInsert this.setup}}
        {{willDestroy this.teardown}}
        {{willDestroy this.cancelPersistDraft}}
      >
        {{#if (and this.showFormattingBar this.editor (not this.disabled))}}
          <div
            aria-label={{i18n "chat.composer.formatting"}}
            class="chat-composer__formatting-bar"
            role="toolbar"
          >
            <ToolbarButtons @data={{this.formattingToolbar}} />
          </div>
        {{/if}}

        <div class="chat-composer__outer-container">
          {{#if this.site.mobileView}}
            <ChatComposerDropdown
              @buttons={{this.dropdownButtons}}
              @isDisabled={{this.disabled}}
            />
          {{/if}}

          <div class="chat-composer__inner-container">
            {{#if this.site.desktopView}}
              <ChatComposerDropdown
                @buttons={{this.dropdownButtons}}
                @isDisabled={{this.disabled}}
              />
            {{/if}}

            <div
              class="chat-composer__input-container"
              {{on "click" this.focusOrPromptLogin}}
            >
              {{#if this.useRichEditor}}
                {{#if this.richEditorComponent}}
                  <this.richEditorComponent
                    @change={{this.onInput}}
                    @class="chat-composer__input"
                    @disabled={{this.disabled}}
                    @extensions={{this.richEditorExtensions}}
                    @focusIn={{this.onTextareaFocusIn}}
                    @focusOut={{this.onTextareaFocusOut}}
                    @keymap={{this.richEditorKeymap}}
                    @onSetup={{this.setupRichEditor}}
                    @placeholder={{this.placeholder}}
                    @toggleRichEditor={{this.toggleEditor}}
                    @trailingParagraph={{false}}
                    @value={{this.draft.message}}
                  />
                {{/if}}
              {{else}}
                <DTextarea
                  autocapitalize="sentences"
                  autocorrect="on"
                  class="chat-composer__input"
                  data-chat-composer-context={{this.context}}
                  disabled={{this.disabled}}
                  id={{this.composerId}}
                  placeholder={{this.placeholder}}
                  rows={{1}}
                  type="text"
                  value={{readonly this.draft.message}}
                  {{preventScrollOnFocus}}
                  {{forceScrollingElementPosition}}
                  {{didInsert this.setupTextareaInteractor}}
                  {{willDestroy this.teardownTextareaInteractor}}
                  {{on "input" this.onInput}}
                  {{on "keydown" this.onKeyDown}}
                  {{on "focusin" this.onTextareaFocusIn}}
                  {{on "focusout" this.onTextareaFocusOut}}
                  {{didInsert this.setupAutocomplete}}
                />
              {{/if}}
            </div>

            {{#each this.inlineButtons as |button|}}
              <DButton
                aria-label={{button.ariaLabel}}
                class={{dConcatClass (concat "-" button.id) button.classNames}}
                disabled={{or this.disabled button.disabled}}
                tabindex={{if button.disabled -1 0}}
                title={{button.title}}
                @icon={{button.icon}}
                {{on "click" (fn this.handleInlineButtonAction button.action)}}
                {{on "focus" (fn this.computeIsFocused true)}}
                {{on "blur" (fn this.computeIsFocused false)}}
              />
            {{/each}}

            <PluginOutlet
              @name="chat-composer-inline-buttons"
              @outletArgs={{lazyHash composer=this channel=@channel}}
            />

            {{#if this.site.desktopView}}
              <DButton
                class="-send"
                disabled={{or this.disabled (not this.sendEnabled)}}
                tabindex={{if this.sendEnabled 0 -1}}
                title={{i18n "chat.composer.send"}}
                @icon="paper-plane"
                {{on "click" this.onSend}}
                {{on "mousedown" this.trapMouseDown}}
                {{on "focus" (fn this.computeIsFocused true)}}
                {{on "blur" (fn this.computeIsFocused false)}}
              />
            {{/if}}
          </div>
          {{#if this.site.mobileView}}
            <DButton
              class="-send"
              disabled={{or this.disabled (not this.sendEnabled)}}
              tabindex={{if this.sendEnabled 0 -1}}
              title={{i18n "chat.composer.send"}}
              @icon="paper-plane"
              {{on "click" this.onSend}}
              {{on "mousedown" this.trapMouseDown}}
              {{on "focus" (fn this.computeIsFocused true)}}
              {{on "blur" (fn this.computeIsFocused false)}}
            />
          {{/if}}
        </div>
      </div>

      {{#if this.canAttachUploads}}
        <ChatComposerUploads
          @composerInputEl={{this.editor.element}}
          @existingUploads={{this.draft.uploads}}
          @fileUploadElementId={{this.fileUploadElementId}}
          @onUploadChanged={{this.onUploadChanged}}
          @uploadDropZone={{@uploadDropZone}}
        />
      {{/if}}

      <div class="chat-replying-indicator-container">
        <ChatReplyingIndicator
          @presenceChannelName={{this.presenceChannelName}}
        />
      </div>
    </div>
  </template>
}
