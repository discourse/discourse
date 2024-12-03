import Component from "@ember/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { schedule, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";
import { resolveCachedShortUrls } from "pretty-text/upload-short-url";
import { Promise } from "rsvp";
import TextareaEditor from "discourse/components/composer/textarea-editor";
import InsertHyperlink from "discourse/components/modal/insert-hyperlink";
import { ajax } from "discourse/lib/ajax";
import { SKIP } from "discourse/lib/autocomplete";
import Toolbar from "discourse/lib/composer/toolbar";
import { hashtagAutocompleteOptions } from "discourse/lib/hashtag-autocomplete";
import { linkSeenHashtagsInContext } from "discourse/lib/hashtag-decorator";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { linkSeenMentions } from "discourse/lib/link-mentions";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { emojiUrlFor, generateCookFunction } from "discourse/lib/text";
import userSearch from "discourse/lib/user-search";
import {
  destroyUserStatuses,
  initUserStatusHtml,
  renderUserStatusHtml,
} from "discourse/lib/user-status-on-autocomplete";
import { isTesting } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import deprecated from "discourse-common/lib/deprecated";
import { getRegister } from "discourse-common/lib/get-owner";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
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
  @service("emoji-store") emojiStore;
  @service modal;

  editorComponent = TextareaEditor;
  textManipulation;

  ready = false;
  lastSel = null;
  showLink = true;
  emojiPickerIsActive = false;
  emojiFilter = "";
  isEditorFocused = false;
  processPreview = true;
  morphingOptions = {
    beforeAttributeUpdated: (element, attributeName) => {
      // Don't morph the open attribute of <details> elements
      return !(element.tagName === "DETAILS" && attributeName === "open");
    },
  };

  init() {
    super.init(...arguments);

    this.register = getRegister(this);
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

    // disable clicking on links in the preview
    this.element
      .querySelector(".d-editor-preview")
      .addEventListener("click", this._handlePreviewLinkClick);
    ``;
  }

  get keymap() {
    const keymap = {};

    const shortcuts = this.get("toolbar.shortcuts");

    Object.keys(shortcuts).forEach((sc) => {
      const button = shortcuts[sc];
      keymap[sc] = () => {
        const customAction = shortcuts[sc].shortcutAction;

        if (customAction) {
          const toolbarEvent = this.newToolbarEvent();
          customAction(toolbarEvent);
        } else {
          button.action(button);
        }
        return false;
      };
    });

    if (this.popupMenuOptions && this.onPopupMenuAction) {
      this.popupMenuOptions.forEach((popupButton) => {
        if (popupButton.shortcut && popupButton.condition) {
          const shortcut =
            `${PLATFORM_KEY_MODIFIER}+${popupButton.shortcut}`.toLowerCase();
          keymap[shortcut] = () => {
            this.onPopupMenuAction(popupButton, this.newToolbarEvent());
            return false;
          };
        }
      });
    }

    keymap["tab"] = () => this.textManipulation.indentSelection("right");
    keymap["shift+tab"] = () => this.textManipulation.indentSelection("left");

    return keymap;
  }

  @bind
  _handlePreviewLinkClick(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    if (event.target.tagName === "A") {
      if (event.target.classList.contains("mention")) {
        this.appEvents.trigger(
          "d-editor:preview-click-user-card",
          event.target,
          event
        );
      }

      if (event.target.classList.contains("mention-group")) {
        this.appEvents.trigger(
          "d-editor:preview-click-group-card",
          event.target,
          event
        );
      }

      event.preventDefault();
      return false;
    }
  }

  @on("willDestroyElement")
  _shutDown() {
    this.element
      .querySelector(".d-editor-preview")
      ?.removeEventListener("click", this._handlePreviewLinkClick);

    this._previewMutationObserver?.disconnect();

    this._cachedCookFunction = null;
  }

  @discourseComputed()
  toolbar() {
    const toolbar = new Toolbar(
      this.getProperties("site", "siteSettings", "showLink", "capabilities")
    );
    toolbar.context = this;

    _createCallbacks.forEach((cb) => cb(toolbar));

    if (this.extraButtons) {
      this.extraButtons(toolbar);
    }

    const firstButton = toolbar.groups.mapBy("buttons").flat().firstObject;
    if (firstButton) {
      firstButton.tabindex = 0;
    }

    return toolbar;
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

    this.set("preview", cooked);

    let unseenMentions, unseenHashtags;

    if (this.siteSettings.enable_diffhtml_preview) {
      const previewElement = this.element.querySelector(".d-editor-preview");
      const cookedElement = previewElement.cloneNode(false);
      cookedElement.innerHTML = cooked;

      unseenMentions = linkSeenMentions(cookedElement, this.siteSettings);

      unseenHashtags = linkSeenHashtagsInContext(
        this.site.hashtag_configurations["topic-composer"],
        cookedElement
      );

      loadOneboxes(
        cookedElement,
        ajax,
        this.topicId,
        this.categoryId,
        this.siteSettings.max_oneboxes_per_post,
        /* refresh */ false,
        /* offline */ true
      );

      resolveCachedShortUrls(this.siteSettings, cookedElement);

      // trigger all the "api.decorateCookedElement"
      this.appEvents.trigger(
        "decorate-non-stream-cooked-element",
        cookedElement
      );

      (await import("morphlex")).morph(
        previewElement,
        cookedElement,
        this.morphingOptions
      );
    }

    schedule("afterRender", () => {
      if (
        this._state !== "inDOM" ||
        !this.element ||
        this.isDestroying ||
        this.isDestroyed
      ) {
        return;
      }

      const previewElement = this.element.querySelector(".d-editor-preview");

      if (previewElement && this.previewUpdated) {
        this.previewUpdated(previewElement, unseenMentions, unseenHashtags);
      }
    });
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
          afterComplete: (value) => {
            this.set("value", value);
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
      template: findRawTemplate("emoji-selector-autocomplete"),
      key: ":",
      afterComplete: (text) => {
        this.set("value", text);
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
          this.emojiStore.track(v.code);
          return `${v.code}:`;
        } else {
          this.textManipulation.autocomplete({ cancel: true });
          this.set("emojiPickerIsActive", true);
          this.set("emojiFilter", v.term);

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
            if (this.emojiStore.favorites.length) {
              return resolve(
                this.emojiStore.favorites
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

          const options = emojiSearch(term, {
            maxResults: 5,
            diversity: this.emojiStore.diversity,
            exclude: emojiDenied,
          });

          return resolve(options);
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
      template: findRawTemplate("user-selector-autocomplete"),
      dataSource: (term) => {
        destroyUserStatuses();
        return userSearch({
          term,
          topicId: this.topicId,
          categoryId: this.categoryId,
          includeGroups: true,
        }).then((result) => {
          initUserStatusHtml(getOwner(this), result.users);
          return result;
        });
      },
      onRender: (options) => renderUserStatusHtml(options),
      key: "@",
      transformComplete: (v) => v.username || v.name,
      afterComplete: (value) => {
        this.set("value", value);

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
    let target = event.target;
    let siblingFinder;
    if (event.code === "ArrowRight") {
      siblingFinder = "nextElementSibling";
    } else if (event.code === "ArrowLeft") {
      siblingFinder = "previousElementSibling";
    } else {
      return true;
    }

    while (
      target.parentNode &&
      !target.parentNode.classList.contains("d-editor-button-bar")
    ) {
      target = target.parentNode;
    }

    let focusable = target[siblingFinder];
    if (focusable) {
      while (
        (focusable.tagName !== "BUTTON" &&
          !focusable.classList.contains("select-kit")) ||
        focusable.classList.contains("hidden")
      ) {
        focusable = focusable[siblingFinder];
      }

      if (focusable?.tagName === "DETAILS") {
        focusable = focusable.querySelector("summary");
      }

      focusable?.focus();
    }

    return true;
  }

  @action
  onEmojiPickerClose() {
    if (!(this.isDestroyed || this.isDestroying)) {
      this.set("emojiPickerIsActive", false);
    }
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
    const selected = this.textManipulation.getSelected(trimLeading);
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
      formatCode: () => this.textManipulation.formatCode(),
      addText: (text) => this.textManipulation.addText(selected, text),
      getText: () => this.value,
      toggleDirection: () => this.textManipulation.toggleDirection(),
      replaceText: (oldVal, newVal, opts) =>
        this.textManipulation.replaceText(oldVal, newVal, opts),
    };
  }

  @action
  emoji() {
    if (this.disabled) {
      return;
    }

    this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
  }

  @action
  toolbarButton(button) {
    if (this.disabled) {
      return;
    }

    const toolbarEvent = this.newToolbarEvent(button.trimLeading);
    if (button.sendAction) {
      return button.sendAction(toolbarEvent);
    } else {
      button.perform(toolbarEvent);
    }
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

    this.modal.show(InsertHyperlink, {
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
    this.set("isEditorFocused", false);
  }

  @action
  setupEditor(textManipulation) {
    this.set("textManipulation", textManipulation);

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

      return () => {
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

    observer.observe(document.querySelector(".d-editor-preview"), {
      childList: true,
      subtree: true,
      attributes: false,
      characterData: true,
    });

    return observer;
  }
}
