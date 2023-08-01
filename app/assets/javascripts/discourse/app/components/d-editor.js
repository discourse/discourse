import { ajax } from "discourse/lib/ajax";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import {
  caretPosition,
  inCodeBlock,
  translateModKey,
} from "discourse/lib/utilities";
import discourseComputed, {
  bind,
  observes,
  on,
} from "discourse-common/utils/decorators";
import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { emojiUrlFor, generateCookFunction } from "discourse/lib/text";
import { schedule, scheduleOnce } from "@ember/runloop";
import Component from "@ember/component";
import I18n from "I18n";
import ItsATrap from "@discourse/itsatrap";
import { Promise } from "rsvp";
import { SKIP } from "discourse/lib/autocomplete";
import { setupHashtagAutocomplete } from "discourse/lib/hashtag-autocomplete";
import deprecated from "discourse-common/lib/deprecated";
import discourseDebounce from "discourse-common/lib/debounce";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { getRegister } from "discourse-common/lib/get-owner";
import { isTesting } from "discourse-common/config/environment";
import { linkSeenHashtags } from "discourse/lib/link-hashtags";
import { linkSeenMentions } from "discourse/lib/link-mentions";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import loadScript from "discourse/lib/load-script";
import { resolveCachedShortUrls } from "pretty-text/upload-short-url";
import { inject as service } from "@ember/service";
import showModal from "discourse/lib/show-modal";
import { siteDir } from "discourse/lib/text-direction";
import { translations } from "pretty-text/emoji/data";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { action, computed } from "@ember/object";
import TextareaTextManipulation, {
  getHead,
} from "discourse/mixins/textarea-text-manipulation";

function getButtonLabel(labelKey, defaultLabel) {
  // use the Font Awesome icon if the label matches the default
  return I18n.t(labelKey) === defaultLabel ? null : labelKey;
}

const FOUR_SPACES_INDENT = "4-spaces-indent";

let _createCallbacks = [];

class Toolbar {
  constructor(opts) {
    const { siteSettings, capabilities } = opts;
    this.shortcuts = {};
    this.context = null;

    this.groups = [
      { group: "fontStyles", buttons: [] },
      { group: "insertions", buttons: [] },
      { group: "extras", buttons: [] },
    ];

    this.addButton({
      id: "bold",
      group: "fontStyles",
      icon: "bold",
      label: getButtonLabel("composer.bold_label", "B"),
      shortcut: "B",
      preventFocus: true,
      trimLeading: true,
      perform: (e) => e.applySurround("**", "**", "bold_text"),
    });

    this.addButton({
      id: "italic",
      group: "fontStyles",
      icon: "italic",
      label: getButtonLabel("composer.italic_label", "I"),
      shortcut: "I",
      preventFocus: true,
      trimLeading: true,
      perform: (e) => e.applySurround("*", "*", "italic_text"),
    });

    if (opts.showLink) {
      this.addButton({
        id: "link",
        group: "insertions",
        shortcut: "K",
        preventFocus: true,
        trimLeading: true,
        sendAction: (event) => this.context.send("showLinkModal", event),
      });
    }

    this.addButton({
      id: "blockquote",
      group: "insertions",
      icon: "quote-right",
      shortcut: "Shift+9",
      preventFocus: true,
      perform: (e) =>
        e.applyList("> ", "blockquote_text", {
          applyEmptyLines: true,
          multiline: true,
        }),
    });

    if (!capabilities.touch) {
      this.addButton({
        id: "code",
        group: "insertions",
        shortcut: "E",
        preventFocus: true,
        trimLeading: true,
        action: (...args) => this.context.send("formatCode", args),
      });

      this.addButton({
        id: "bullet",
        group: "extras",
        icon: "list-ul",
        shortcut: "Shift+8",
        title: "composer.ulist_title",
        preventFocus: true,
        perform: (e) => e.applyList("* ", "list_item"),
      });

      this.addButton({
        id: "list",
        group: "extras",
        icon: "list-ol",
        shortcut: "Shift+7",
        title: "composer.olist_title",
        preventFocus: true,
        perform: (e) =>
          e.applyList(
            (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
            "list_item"
          ),
      });
    }

    if (siteSettings.support_mixed_text_direction) {
      this.addButton({
        id: "toggle-direction",
        group: "extras",
        icon: "exchange-alt",
        shortcut: "Shift+6",
        title: "composer.toggle_direction",
        preventFocus: true,
        perform: (e) => e.toggleDirection(),
      });
    }

    this.groups[this.groups.length - 1].lastGroup = true;
  }

  addButton(button) {
    const g = this.groups.findBy("group", button.group);
    if (!g) {
      throw new Error(`Couldn't find toolbar group ${button.group}`);
    }

    const createdButton = {
      id: button.id,
      tabindex: button.tabindex || "-1",
      className: button.className || button.id,
      label: button.label,
      icon: button.label ? null : button.icon || button.id,
      action: button.action || ((a) => this.context.send("toolbarButton", a)),
      perform: button.perform || function () {},
      trimLeading: button.trimLeading,
      popupMenu: button.popupMenu || false,
      preventFocus: button.preventFocus || false,
    };

    if (button.sendAction) {
      createdButton.sendAction = button.sendAction;
    }

    const title = I18n.t(button.title || `composer.${button.id}_title`);
    if (button.shortcut) {
      const shortcutTitle = `${translateModKey(
        PLATFORM_KEY_MODIFIER + "+"
      )}${translateModKey(button.shortcut)}`;

      createdButton.title = `${title} (${shortcutTitle})`;
      this.shortcuts[
        `${PLATFORM_KEY_MODIFIER}+${button.shortcut}`.toLowerCase()
      ] = createdButton;
    } else {
      createdButton.title = title;
    }

    if (button.unshift) {
      g.buttons.unshift(createdButton);
    } else {
      g.buttons.push(createdButton);
    }
  }
}

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

export default Component.extend(TextareaTextManipulation, {
  classNames: ["d-editor"],
  ready: false,
  lastSel: null,
  _itsatrap: null,
  showLink: true,
  emojiPickerIsActive: false,
  emojiFilter: "",
  emojiStore: service("emoji-store"),
  isEditorFocused: false,
  processPreview: true,
  composerFocusSelector: "#reply-control .d-editor-input",

  selectedFormTemplateId: computed("formTemplateIds", {
    get() {
      if (this._selectedFormTemplateId) {
        return this._selectedFormTemplateId;
      }

      return this.formTemplateIds?.[0];
    },

    set(key, value) {
      return (this._selectedFormTemplateId = value);
    },
  }),

  @action
  updateSelectedFormTemplateId(formTemplateId) {
    this.selectedFormTemplateId = formTemplateId;
  },

  @discourseComputed("formTemplateIds", "replyingToTopic", "editingPost")
  showFormTemplateForm(formTemplateIds, replyingToTopic, editingPost) {
    // TODO(@keegan): Remove !editingPost once we add edit/draft support for form templates
    if (formTemplateIds?.length > 0 && !replyingToTopic && !editingPost) {
      return true;
    }

    return false;
  },

  @discourseComputed("placeholder")
  placeholderTranslated(placeholder) {
    if (placeholder) {
      return I18n.t(placeholder);
    }
    return null;
  },

  _readyNow() {
    this.set("ready", true);

    if (this.autofocus) {
      this._textarea.focus();
    }
  },

  init() {
    this._super(...arguments);

    this.register = getRegister(this);
  },

  didInsertElement() {
    this._super(...arguments);

    this._previewMutationObserver = this._disablePreviewTabIndex();

    this._textarea = this.element.querySelector("textarea.d-editor-input");
    this._$textarea = $(this._textarea);
    this._applyEmojiAutocomplete(this._$textarea);
    this._applyHashtagAutocomplete(this._$textarea);

    scheduleOnce("afterRender", this, this._readyNow);

    this._itsatrap = new ItsATrap(this._textarea);
    const shortcuts = this.get("toolbar.shortcuts");

    Object.keys(shortcuts).forEach((sc) => {
      const button = shortcuts[sc];
      this._itsatrap.bind(sc, () => {
        button.action(button);
        return false;
      });
    });

    this._itsatrap.bind("tab", () => this.indentSelection("right"));
    this._itsatrap.bind("shift+tab", () => this.indentSelection("left"));
    this._itsatrap.bind(`${PLATFORM_KEY_MODIFIER}+shift+.`, () =>
      this.send("insertCurrentTime")
    );

    // disable clicking on links in the preview
    this.element
      .querySelector(".d-editor-preview")
      .addEventListener("click", this._handlePreviewLinkClick);

    if (this.composerEvents) {
      this.appEvents.on("composer:insert-block", this, "insertBlock");
      this.appEvents.on("composer:insert-text", this, "insertText");
      this.appEvents.on("composer:replace-text", this, "replaceText");
      this.appEvents.on("composer:apply-surround", this, "_applySurround");
      this.appEvents.on(
        "composer:indent-selected-text",
        this,
        "indentSelection"
      );
    }
  },

  @bind
  _handlePreviewLinkClick(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    if (event.target.tagName === "A") {
      if (event.target.classList.contains("mention")) {
        this.appEvents.trigger(
          "click.discourse-preview-user-card-mention",
          $(event.target)
        );
      }

      if (event.target.classList.contains("mention-group")) {
        this.appEvents.trigger(
          "click.discourse-preview-group-card-mention-group",
          $(event.target)
        );
      }

      event.preventDefault();
      return false;
    }
  },

  @on("willDestroyElement")
  _shutDown() {
    if (this.composerEvents) {
      this.appEvents.off("composer:insert-block", this, "insertBlock");
      this.appEvents.off("composer:insert-text", this, "insertText");
      this.appEvents.off("composer:replace-text", this, "replaceText");
      this.appEvents.off("composer:apply-surround", this, "_applySurround");
      this.appEvents.off(
        "composer:indent-selected-text",
        this,
        "indentSelection"
      );
    }

    this._itsatrap?.destroy();
    this._itsatrap = null;

    this.element
      .querySelector(".d-editor-preview")
      ?.removeEventListener("click", this._handlePreviewLinkClick);

    this._previewMutationObserver?.disconnect();

    if (isTesting()) {
      this.element.removeEventListener("paste", this.paste);
    }

    this._cachedCookFunction = null;
  },

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
  },

  cachedCookAsync(text) {
    if (this._cachedCookFunction) {
      return Promise.resolve(this._cachedCookFunction(text));
    }

    const markdownOptions = this.markdownOptions || {};
    return generateCookFunction(markdownOptions).then((cook) => {
      this._cachedCookFunction = cook;
      return cook(text);
    });
  },

  _updatePreview() {
    if (this._state !== "inDOM" || !this.processPreview) {
      return;
    }

    const value = this.value;

    this.cachedCookAsync(value).then((cooked) => {
      if (this.isDestroyed) {
        return;
      }

      if (this.preview === cooked) {
        return;
      }

      this.set("preview", cooked);

      let previewPromise = Promise.resolve();

      if (this.siteSettings.enable_diffhtml_preview) {
        const cookedElement = document.createElement("div");
        cookedElement.innerHTML = cooked;

        linkSeenHashtags(cookedElement);
        linkSeenMentions(cookedElement, this.siteSettings);
        resolveCachedShortUrls(this.siteSettings, cookedElement);
        loadOneboxes(
          cookedElement,
          ajax,
          null,
          null,
          this.siteSettings.max_oneboxes_per_post,
          false,
          true
        );

        previewPromise = loadScript("/javascripts/diffhtml.min.js").then(() => {
          const previewElement =
            this.element.querySelector(".d-editor-preview");
          // This is a workaround for a known bug in diffHTML
          // https://github.com/tbranyen/diffhtml/issues/217#issuecomment-1479956332
          window.diff.release(previewElement);
          window.diff.innerHTML(previewElement, cookedElement.innerHTML);
        });
      }

      previewPromise.then(() => {
        schedule("afterRender", () => {
          if (this._state !== "inDOM" || !this.element) {
            return;
          }

          const preview = this.element.querySelector(".d-editor-preview");
          if (!preview) {
            return;
          }

          if (this.previewUpdated) {
            this.previewUpdated(preview);
          }
        });
      });
    });
  },

  @observes("ready", "value", "processPreview")
  _watchForChanges() {
    if (!this.ready) {
      return;
    }

    // Debouncing in test mode is complicated
    if (isTesting()) {
      this._updatePreview();
    } else {
      discourseDebounce(this, this._updatePreview, 30);
    }
  },

  _applyHashtagAutocomplete() {
    setupHashtagAutocomplete(
      this.site.hashtag_configurations["topic-composer"],
      this._$textarea,
      this.siteSettings,
      {
        afterComplete: (value) => {
          this.set("value", value);
          schedule("afterRender", this, this.focusTextArea);
        },
      }
    );
  },

  _applyEmojiAutocomplete($textarea) {
    if (!this.siteSettings.enable_emoji) {
      return;
    }

    $textarea.autocomplete({
      template: findRawTemplate("emoji-selector-autocomplete"),
      key: ":",
      afterComplete: (text) => {
        this.set("value", text);
        schedule("afterRender", this, this.focusTextArea);
      },

      onKeyUp: (text, cp) => {
        if (inCodeBlock(text, cp)) {
          return false;
        }

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
          $textarea.autocomplete({ cancel: true });
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
              list.push({ label: I18n.t("composer.more_emoji"), term });
            }
            return list;
          });
      },

      triggerRule: (textarea) =>
        !inCodeBlock(textarea.value, caretPosition(textarea)),
    });
  },

  _applyList(sel, head, exampleKey, opts) {
    if (sel.value.includes("\n")) {
      this.applySurround(sel, head, "", exampleKey, opts);
    } else {
      const [hval, hlen] = getHead(head);
      if (sel.start === sel.end) {
        sel.value = I18n.t(`composer.${exampleKey}`);
      }

      const trimmedPre = sel.pre.trim();
      const number = sel.value.startsWith(hval)
        ? sel.value.slice(hlen)
        : `${hval}${sel.value}`;
      const preLines = trimmedPre.length ? `${trimmedPre}\n\n` : "";

      const trimmedPost = sel.post.trim();
      const post = trimmedPost.length ? `\n\n${trimmedPost}` : trimmedPost;

      this.set("value", `${preLines}${number}${post}`);
      this.selectText(preLines.length, number.length);
    }
  },

  _applySurround(head, tail, exampleKey, opts) {
    const selected = this.getSelected();
    this.applySurround(selected, head, tail, exampleKey, opts);
  },

  _toggleDirection() {
    let currentDir = this._$textarea.attr("dir")
        ? this._$textarea.attr("dir")
        : siteDir(),
      newDir = currentDir === "ltr" ? "rtl" : "ltr";

    this._$textarea.attr("dir", newDir).focus();
  },

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
  },

  @action
  onEmojiPickerClose() {
    if (!(this.isDestroyed || this.isDestroying)) {
      this.set("emojiPickerIsActive", false);
    }
  },

  actions: {
    emoji() {
      if (this.disabled) {
        return;
      }

      this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
    },

    toolbarButton(button) {
      if (this.disabled) {
        return;
      }

      const selected = this.getSelected(button.trimLeading);
      const toolbarEvent = {
        selected,
        selectText: (from, length) =>
          this.selectText(from, length, { scroll: false }),
        applySurround: (head, tail, exampleKey, opts) =>
          this.applySurround(selected, head, tail, exampleKey, opts),
        applyList: (head, exampleKey, opts) =>
          this._applyList(selected, head, exampleKey, opts),
        formatCode: (...args) => this.send("formatCode", args),
        addText: (text) => this.addText(selected, text),
        getText: () => this.value,
        toggleDirection: () => this._toggleDirection(),
      };

      if (button.sendAction) {
        return button.sendAction(toolbarEvent);
      } else {
        button.perform(toolbarEvent);
      }
    },

    showLinkModal(toolbarEvent) {
      if (this.disabled) {
        return;
      }

      let linkText = "";
      this._lastSel = toolbarEvent.selected;

      if (this._lastSel) {
        linkText = this._lastSel.value;
      }

      showModal("insert-hyperlink").setProperties({
        linkText,
        toolbarEvent,
      });
    },

    formatCode() {
      if (this.disabled) {
        return;
      }

      const sel = this.getSelected("", { lineVal: true });
      const selValue = sel.value;
      const hasNewLine = selValue.includes("\n");
      const isBlankLine = sel.lineVal.trim().length === 0;
      const isFourSpacesIndent =
        this.siteSettings.code_formatting_style === FOUR_SPACES_INDENT;

      if (!hasNewLine) {
        if (selValue.length === 0 && isBlankLine) {
          if (isFourSpacesIndent) {
            const example = I18n.t(`composer.code_text`);
            this.set("value", `${sel.pre}    ${example}${sel.post}`);
            return this.selectText(sel.pre.length + 4, example.length);
          } else {
            return this.applySurround(sel, "```\n", "\n```", "paste_code_text");
          }
        } else {
          return this.applySurround(sel, "`", "`", "code_title");
        }
      } else {
        if (isFourSpacesIndent) {
          return this.applySurround(sel, "    ", "", "code_text");
        } else {
          const preNewline = sel.pre[-1] !== "\n" && sel.pre !== "" ? "\n" : "";
          const postNewline = sel.post[0] !== "\n" ? "\n" : "";
          return this.addText(
            sel,
            `${preNewline}\`\`\`\n${sel.value}\n\`\`\`${postNewline}`
          );
        }
      }
    },

    insertCurrentTime() {
      const sel = this.getSelected("", { lineVal: true });
      const timezone = this.currentUser.user_option.timezone;
      const time = moment().format("HH:mm:ss");
      const date = moment().format("YYYY-MM-DD");

      this.addText(sel, `[date=${date} time=${time} timezone="${timezone}"]`);
    },

    focusIn() {
      this.set("isEditorFocused", true);
    },

    focusOut() {
      this.set("isEditorFocused", false);
    },
  },

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
  },
});
