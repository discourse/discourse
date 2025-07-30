import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { cancel, schedule, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { observes, on as onEvent } from "@ember-decorators/object";
import curryComponent from "ember-curry-component";
import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";
import { Promise } from "rsvp";
import { not } from "truth-helpers";
import TextareaEditor from "discourse/components/composer/textarea-editor";
import ToggleSwitch from "discourse/components/composer/toggle-switch";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DEditorPreview from "discourse/components/d-editor-preview";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import UpsertHyperlink from "discourse/components/modal/upsert-hyperlink";
import PluginOutlet from "discourse/components/plugin-outlet";
import PopupInputTip from "discourse/components/popup-input-tip";
import renderEmojiAutocomplete from "discourse/lib/autocomplete/emoji";
import userAutocomplete from "discourse/lib/autocomplete/user";
import Toolbar from "discourse/lib/composer/toolbar";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { isTesting } from "discourse/lib/environment";
import { getRegister } from "discourse/lib/get-owner";
import { hashtagAutocompleteOptions } from "discourse/lib/hashtag-autocomplete";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import loadEmojiSearchAliases from "discourse/lib/load-emoji-search-aliases";
import loadRichEditor from "discourse/lib/load-rich-editor";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";
import { emojiUrlFor, generateCookFunction } from "discourse/lib/text";
import userSearch from "discourse/lib/user-search";
import {
  destroyUserStatuses,
  initUserStatusHtml,
  renderUserStatusHtml,
} from "discourse/lib/user-status-on-autocomplete";
import { SKIP } from "discourse/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";

let _createCallbacks = [];

export function addToolbarCallback(func) {
  _createCallbacks.push(func);
}
export function clearToolbarCallbacks() {
  _createCallbacks = [];
}

export function onToolbarCreate(func) {
  deprecated("`onToolbarCreate` is deprecated, use the plugin api instead.", {
    id: "discourse.d-editor.on-toolbar-create",
  });
  addToolbarCallback(func);
}

@classNames("d-editor")
export default class DEditor extends Component {
  @service emojiStore;
  @service modal;
  @service menu;

  @tracked editorComponent;
  /** @type {TextManipulation} */
  @tracked textManipulation;
  @tracked replacedToolbarInstance;

  @tracked preview;

  ready = false;
  lastSel = null;
  showLink = true;
  isEditorFocused = false;
  processPreview = true;
  morphingOptions = {
    beforeAttributeUpdated: (element, attributeName) => {
      // Don't morph the open attribute of <details> elements
      return !(element.tagName === "DETAILS" && attributeName === "open");
    },
  };

  async init() {
    super.init(...arguments);

    this.register = getRegister(this);

    this.setupToolbar();

    if (this.siteSettings.rich_editor) {
      // TODO (martin) Remove this once we are sure all users have migrated
      // to the new rich editor preference, or a few months after the 3.5 release.
      await this.handleOldRichEditorPreference();

      if (this.currentUser.useRichEditor) {
        this.editorComponent = await loadRichEditor();
      }
    }

    this.editorComponent ??= TextareaEditor;
  }

  setupToolbar() {
    this.toolbar = new Toolbar(
      this.getProperties("siteSettings", "showLink", "capabilities")
    );
    this.toolbar.context = this;

    _createCallbacks.forEach((cb) => cb(this.toolbar));

    if (this.extraButtons) {
      this.extraButtons(this.toolbar);
    }
  }

  async handleOldRichEditorPreference() {
    const oldValue = this.keyValueStore.get("d-editor-prefers-rich-editor");

    if (!oldValue) {
      return;
    }

    await this.#saveRichEditorPreference(
      oldValue === "true"
        ? USER_OPTION_COMPOSITION_MODES.rich
        : USER_OPTION_COMPOSITION_MODES.markdown
    ).finally(() => {
      this.keyValueStore.remove("d-editor-prefers-rich-editor");
    });
  }

  @discourseComputed("placeholder")
  placeholderTranslated(placeholder) {
    if (placeholder) {
      return i18n(placeholder);
    }
    return null;
  }

  _readyNow() {
    this.set("ready", true);

    if (this.autofocus) {
      this.textManipulation.focus();
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this._previewMutationObserver = this._disablePreviewTabIndex();
  }

  get keymap() {
    const keymap = {};

    // These are defined in lib/composer/toolbar.js via addButton.
    // It includes shortcuts for top level toolbar buttons, as well
    // as the toolbar popup menu option shortcuts.

    // TODO (martin) Might be nice to automatically add these shortcuts
    // to keyboard-shortcuts-help.gjs at some point (the modal launched with
    // ?)
    const shortcuts = this.get("toolbar.shortcuts");
    Object.keys(shortcuts).forEach((sc) => {
      const button = shortcuts[sc];
      keymap[sc] = () => {
        const customAction = shortcuts[sc].shortcutAction;

        if (customAction) {
          const toolbarEvent = this.newToolbarEvent();
          if (!button.condition || button.condition(toolbarEvent)) {
            customAction(toolbarEvent);
          }
        } else {
          button.action(button);
        }
        return false;
      };
    });

    // This refers to the "special" composer toolbar popup menu which
    // is launched from the (+) button in the toolbar. This menu is customizable
    // via the plugin API, so it differs from regular toolbar button definitions
    // from toolbar.js
    this.popupMenuOptions?.forEach((popupButton) => {
      if (popupButton.shortcut && popupButton.condition) {
        const shortcut =
          `${PLATFORM_KEY_MODIFIER}+${popupButton.shortcut}`.toLowerCase();
        keymap[shortcut] = () => {
          this.onPopupMenuAction(
            {
              ...popupButton,
              action: popupButton.shortcutAction ?? popupButton.action,
            },
            this.newToolbarEvent()
          );
          return false;
        };
      }
    });

    // indentSelection returns true if the selection was indented
    // itsatrap expects the return value to be false to prevent default
    keymap["tab"] = () => !this.textManipulation.indentSelection("right");
    keymap["shift+tab"] = () => !this.textManipulation.indentSelection("left");
    if (this.siteSettings.rich_editor) {
      keymap["ctrl+m"] = () => this.toggleRichEditor();
    }

    return keymap;
  }

  @onEvent("willDestroyElement")
  _shutDown() {
    this._previewMutationObserver?.disconnect();
    cancel(this._debounceSaveRichEditorPreference);

    this._cachedCookFunction = null;
  }

  async cachedCookAsync(text, options) {
    this._cachedCookFunction ||= await generateCookFunction(options || {});
    return await this._cachedCookFunction(text);
  }

  async _updatePreview() {
    if (
      this._state !== "inDOM" ||
      !this.processPreview ||
      this.isDestroying ||
      this.isDestroyed
    ) {
      return;
    }

    const cooked = await this.cachedCookAsync(this.value, this.markdownOptions);

    if (this.preview === cooked || this.isDestroying || this.isDestroyed) {
      return;
    }

    this.preview = cooked;
  }

  @observes("ready", "value", "processPreview")
  async _watchForChanges() {
    if (!this.ready) {
      return;
    }

    // Debouncing in test mode is complicated
    if (isTesting()) {
      await this._updatePreview();
    } else {
      discourseDebounce(this, this._updatePreview, 30);
    }
  }

  _applyHashtagAutocomplete() {
    this.textManipulation.autocomplete(
      hashtagAutocompleteOptions(
        this.site.hashtag_configurations["topic-composer"],
        this.siteSettings,
        {
          afterComplete: () => {
            schedule(
              "afterRender",
              this.textManipulation,
              this.textManipulation.blurAndFocus
            );
          },
        }
      )
    );
  }

  _applyEmojiAutocomplete() {
    if (!this.siteSettings.enable_emoji) {
      return;
    }

    this.textManipulation.autocomplete({
      template: renderEmojiAutocomplete,
      key: ":",
      afterComplete: () => {
        schedule(
          "afterRender",
          this.textManipulation,
          this.textManipulation.blurAndFocus
        );
      },

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
          this.emojiStore.trackEmojiForContext(v.code, "topic");
          return `${v.code}:`;
        } else {
          this.textManipulation.autocomplete({ cancel: true });

          const menuOptions = {
            identifier: "emoji-picker",
            component: EmojiPickerDetached,
            modalForMobile: true,
            data: {
              didSelectEmoji: (emoji) => {
                this.textManipulation.emojiSelected(emoji);
              },
              term: v.term,
            },
          };

          const caretCoords =
            this.textManipulation.autocompleteHandler.getCaretCoords(
              this.textManipulation.autocompleteHandler.getCaretPosition()
            );

          const rect = document
            .querySelector(".d-editor-input")
            .getBoundingClientRect();

          const marginLeft = 18;
          const marginTop = 10;

          const virtualElement = {
            getBoundingClientRect: () => ({
              left: rect.left + caretCoords.left + marginLeft,
              top: rect.top + caretCoords.top + marginTop,
              width: 0,
              height: 0,
            }),
          };
          this.menuInstance = this.menu.show(virtualElement, menuOptions);
          return "";
        }
      },

      dataSource: (term) => {
        return new Promise((resolve) => {
          const full = `:${term}`;
          term = term.toLowerCase();

          if (term.length < this.siteSettings.emoji_autocomplete_min_chars) {
            return resolve(SKIP);
          }

          if (term === "") {
            const favorites = this.emojiStore.favoritesForContext("topic");
            if (favorites.length) {
              return resolve(
                favorites
                  .filter((f) => !this.site.denied_emojis?.includes(f))
                  .slice(0, 5)
              );
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
          const emojiTranslation =
            this.get("site.custom_emoji_translation") || {};
          const allTranslations = Object.assign(
            {},
            translations,
            emojiTranslation
          );
          if (allTranslations[full]) {
            return resolve([allTranslations[full]]);
          }

          const emojiDenied = this.get("site.denied_emojis") || [];
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

          loadEmojiSearchAliases().then((searchAliases) => {
            const options = emojiSearch(term, {
              maxResults: 5,
              diversity: this.emojiStore.diversity,
              exclude: emojiDenied,
              searchAliases,
            });

            resolve(options);
          });
        })
          .then((list) => {
            if (list === SKIP) {
              return [];
            }

            return list.map((code) => {
              return { code, src: emojiUrlFor(code) };
            });
          })
          .then((list) => {
            if (list.length) {
              list.push({ label: i18n("composer.more_emoji"), term });
            }
            return list;
          });
      },

      triggerRule: async () => !(await this.textManipulation.inCodeBlock()),
    });
  }

  _applyMentionAutocomplete() {
    if (!this.siteSettings.enable_mentions) {
      return;
    }

    this.textManipulation.autocomplete({
      template: userAutocomplete,
      dataSource: (term) => {
        destroyUserStatuses();
        return userSearch({
          term,
          topicId: this.topicId,
          categoryId: this.categoryId,
          includeGroups: true,
          prioritizedUserId: this.replyingToUserId,
        }).then((result) => {
          initUserStatusHtml(getOwner(this), result.users);
          return result;
        });
      },
      onRender: (options) => renderUserStatusHtml(options),
      key: "@",
      transformComplete: (v) => v.username || v.name,
      afterComplete: () => {
        schedule(
          "afterRender",
          this.textManipulation,
          this.textManipulation.blurAndFocus
        );
      },
      triggerRule: async () => !(await this.textManipulation.inCodeBlock()),
      onClose: destroyUserStatuses,
    });
  }

  @action
  rovingButtonBar(event) {
    return rovingButtonBar(event, "d-editor-button-bar");
  }

  /**
   * Represents a toolbar event object passed to toolbar buttons.
   *
   * @typedef {Object} ToolbarEvent
   * @property {function} applySurround - Applies surrounding text
   * @property {function} formatCode - Formats as code
   * @property {function} replaceText - Replaces text
   * @property {function} selectText - Selects a range of text
   * @property {function} toggleDirection - Toggles text direction
   * @property {function} getText - Gets the text
   * @property {function} addText - Adds text
   * @property {function} applyList - Applies a list format
   * @property {*} selected - The current selection
   */

  /**
   * Creates a new toolbar event object
   *
   * @param {boolean} trimLeading - Whether to trim leading whitespace
   * @returns {ToolbarEvent} An object with toolbar event actions
   */
  newToolbarEvent(trimLeading) {
    const selected = this.textManipulation.getSelected(trimLeading, {
      lineVal: true,
    });
    return {
      selected,
      selectText: (from, length) =>
        this.textManipulation.selectText(from, length, { scroll: false }),
      applySurround: (head, tail, exampleKey, opts) =>
        this.textManipulation.applySurround(
          selected,
          head,
          tail,
          exampleKey,
          opts
        ),
      applyList: (head, exampleKey, opts) =>
        this.textManipulation.applyList(selected, head, exampleKey, opts),
      applyHeading: (level, exampleKey) =>
        this.textManipulation.applyHeading(selected, level, exampleKey),
      formatCode: () => this.textManipulation.formatCode(),
      addText: (text) => this.textManipulation.addText(selected, text),
      getText: () => this.value,
      toggleDirection: () => this.textManipulation.toggleDirection(),
      replaceText: (oldVal, newVal, opts) =>
        this.textManipulation.replaceText(oldVal, newVal, opts),
    };
  }

  @action
  showLinkModal(toolbarEvent) {
    if (this.disabled) {
      return;
    }

    let linkText = "";
    this._lastSel = toolbarEvent.selected;

    if (this._lastSel) {
      linkText = this._lastSel.value;
    }

    this.modal.show(UpsertHyperlink, {
      model: {
        linkText,
        toolbarEvent,
      },
    });
  }

  @action
  handleFocusIn() {
    this.set("isEditorFocused", true);
  }

  @action
  handleFocusOut() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.set("isEditorFocused", false);
  }

  /**
   * Sets up the editor with the given text manipulation instance
   *
   * @param {TextManipulation} textManipulation The text manipulation instance
   * @returns {(() => void)} destructor function
   */
  @action
  setupEditor(textManipulation) {
    this.textManipulation = textManipulation;

    const destroyEvents = this.setupEvents();

    this.element.addEventListener("paste", textManipulation.paste);

    this._applyEmojiAutocomplete();
    this._applyHashtagAutocomplete();
    this._applyMentionAutocomplete();

    const destroyEditor = this.onSetup?.(textManipulation);

    scheduleOnce("afterRender", this, this._readyNow);

    return () => {
      destroyEvents?.();

      this.element?.removeEventListener("paste", textManipulation.paste);

      textManipulation.autocomplete("destroy");

      destroyEditor?.();
    };
  }

  @action
  async toggleRichEditor() {
    // The ProsemirrorEditor component is loaded here, adding this comment because
    // otherwise it's hard to find where the component is rendered by name.
    this.editorComponent = this.isRichEditorEnabled
      ? TextareaEditor
      : await loadRichEditor();

    const preference = this.isRichEditorEnabled
      ? USER_OPTION_COMPOSITION_MODES.rich
      : USER_OPTION_COMPOSITION_MODES.markdown;
    this.#debounceSaveRichEditorPreference(preference);
  }

  #debounceSaveRichEditorPreference(preference) {
    this._debounceSaveRichEditorPreference = discourseDebounce(
      this,
      this.#saveRichEditorPreference,
      preference,
      1000
    );
  }

  #saveRichEditorPreference(preference) {
    this.currentUser.set("user_option.composition_mode", preference);
    return this.currentUser.save(["composition_mode"]);
  }

  @action
  replaceToolbar(toolbarInstance) {
    this.replacedToolbarInstance = toolbarInstance;
  }

  @action
  resetToolbar() {
    this.replacedToolbarInstance = null;
  }

  @action
  onChange(event) {
    this.set("value", event?.target?.value);
    this.change?.(event);
  }

  get isRichEditorEnabled() {
    return this.editorComponent !== TextareaEditor;
  }

  setupEvents() {
    const textManipulation = this.textManipulation;

    if (this.composerEvents) {
      this.appEvents.on(
        "composer:insert-block",
        textManipulation,
        "insertBlock"
      );
      this.appEvents.on("composer:insert-text", textManipulation, "insertText");
      this.appEvents.on(
        "composer:replace-text",
        textManipulation,
        "replaceText"
      );
      this.appEvents.on(
        "composer:apply-surround",
        textManipulation,
        "applySurroundSelection"
      );
      this.appEvents.on(
        "composer:indent-selected-text",
        textManipulation,
        "indentSelection"
      );

      const replaceToolbar = ({ component, data }) => {
        this.replacedToolbarComponent = curryComponent(
          component,
          { data },
          getOwner(this)
        );
      };

      this.appEvents.on("composer:replace-toolbar", replaceToolbar);
      this.appEvents.on("composer:reset-toolbar", this, "resetToolbar");

      return () => {
        this.appEvents.off("composer:replace-toolbar", replaceToolbar);
        this.appEvents.off("composer:reset-toolbar", this, "resetToolbar");

        this.appEvents.off(
          "composer:insert-block",
          textManipulation,
          "insertBlock"
        );
        this.appEvents.off(
          "composer:insert-text",
          textManipulation,
          "insertText"
        );
        this.appEvents.off(
          "composer:replace-text",
          textManipulation,
          "replaceText"
        );
        this.appEvents.off(
          "composer:apply-surround",
          textManipulation,
          "applySurroundSelection"
        );
        this.appEvents.off(
          "composer:indent-selected-text",
          textManipulation,
          "indentSelection"
        );
      };
    }
  }

  _disablePreviewTabIndex() {
    const observer = new MutationObserver(function () {
      document.querySelectorAll(".d-editor-preview a").forEach((anchor) => {
        anchor.setAttribute("tabindex", "-1");
      });
    });

    observer.observe(document.querySelector(".d-editor-preview-wrapper"), {
      childList: true,
      subtree: true,
      attributes: false,
      characterData: true,
    });

    return observer;
  }

  <template>
    <div
      class="d-editor-container
        {{if
          this.siteSettings.rich_editor
          'd-editor-container--rich-editor-enabled'
        }}"
    >
      <div class="d-editor-textarea-column">
        {{yield}}

        <div
          class="d-editor-textarea-wrapper
            {{if this.disabled 'disabled'}}
            {{if this.isEditorFocused 'in-focus'}}"
        >

          {{#if this.replacedToolbarInstance}}
            <div class="d-editor-button-bar --replaced-toolbar" role="toolbar">
              <DButton
                @action={{this.resetToolbar}}
                @icon="angle-left"
                @preventFocus={{true}}
                @onKeyDown={{this.rovingButtonBar}}
                class="d-editor-button-bar__back"
              />
              <ToolbarButtons
                @data={{this.replacedToolbarInstance}}
                @rovingButtonBar={{this.rovingButtonBar}}
                @isFirst={{false}}
              />
            </div>
          {{else}}
            <div class="d-editor-button-bar" role="toolbar">
              {{#if this.siteSettings.rich_editor}}
                <ToggleSwitch
                  @preventFocus={{true}}
                  @disabled={{@disableSubmit}}
                  @state={{this.isRichEditorEnabled}}
                  {{on "click" this.toggleRichEditor}}
                  {{on "keydown" this.rovingButtonBar}}
                />
              {{/if}}

              <ToolbarButtons
                @data={{this.toolbar}}
                @rovingButtonBar={{this.rovingButtonBar}}
                @isFirst={{not this.siteSettings.rich_editor}}
              />
            </div>
          {{/if}}

          <ConditionalLoadingSpinner @condition={{this.loading}} />
          <this.editorComponent
            @class="d-editor-input"
            @onSetup={{this.setupEditor}}
            @markdownOptions={{this.markdownOptions}}
            @keymap={{this.keymap}}
            @value={{this.value}}
            @placeholder={{this.placeholderTranslated}}
            @disabled={{this.disabled}}
            @change={{this.onChange}}
            @focusIn={{this.handleFocusIn}}
            @focusOut={{this.handleFocusOut}}
            @categoryId={{@categoryId}}
            @topicId={{@topicId}}
            @id={{this.textAreaId}}
            @replaceToolbar={{this.replaceToolbar}}
          />
          <PopupInputTip @validation={{this.validation}} />
          <PluginOutlet
            @name="after-d-editor"
            @connectorTagName="div"
            @outletArgs={{this.outletArgs}}
          />
        </div>
      </div>

      {{#if @hijackPreview}}
        <div class="d-editor-preview-wrapper">
          <@hijackPreview.component @model={{@hijackPreview.model}} />
        </div>
      {{else}}
        <DEditorPreview
          @preview={{this.preview}}
          @forcePreview={{this.forcePreview}}
          @onPreviewUpdated={{this.previewUpdated}}
          @outletArgs={{this.outletArgs}}
        />
      {{/if}}
    </div>
  </template>
}
