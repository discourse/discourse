import { ajax } from "discourse/lib/ajax";
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
import { later, schedule, scheduleOnce } from "@ember/runloop";
import Component from "@ember/component";
import I18n from "I18n";
import ItsATrap from "@discourse/itsatrap";
import { Promise } from "rsvp";
import { SKIP } from "discourse/lib/autocomplete";
import { categoryHashtagTriggerRule } from "discourse/lib/category-hashtags";
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
import { search as searchCategoryTag } from "discourse/lib/category-tag-search";
import { inject as service } from "@ember/service";
import showModal from "discourse/lib/show-modal";
import { siteDir } from "discourse/lib/text-direction";
import { translations } from "pretty-text/emoji/data";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { action } from "@ember/object";
import TextareaTextManipulation from "discourse/mixins/textarea-text-manipulation";

// Our head can be a static string or a function that returns a string
// based on input (like for numbered lists).
function getHead(head, prev) {
  if (typeof head === "string") {
    return [head, head.length];
  } else {
    return getHead(head(prev));
  }
}

function getButtonLabel(labelKey, defaultLabel) {
  // use the Font Awesome icon if the label matches the default
  return I18n.t(labelKey) === defaultLabel ? null : labelKey;
}

const OP = {
  NONE: 0,
  REMOVED: 1,
  ADDED: 2,
};

const FOUR_SPACES_INDENT = "4-spaces-indent";

let _createCallbacks = [];

class Toolbar {
  constructor(opts) {
    const { site, siteSettings } = opts;
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

    this.addButton({
      id: "code",
      group: "insertions",
      shortcut: "E",
      preventFocus: true,
      trimLeading: true,
      action: (...args) => this.context.send("formatCode", args),
    });

    if (!site.mobileView) {
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
      const mac = /Mac|iPod|iPhone|iPad/.test(navigator.platform);
      const mod = mac ? "Meta" : "Ctrl";

      const shortcutTitle = `${translateModKey(mod + "+")}${translateModKey(
        button.shortcut
      )}`;

      createdButton.title = `${title} (${shortcutTitle})`;
      this.shortcuts[`${mod}+${button.shortcut}`.toLowerCase()] = createdButton;
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
  deprecated("`onToolbarCreate` is deprecated, use the plugin api instead.");
  addToolbarCallback(func);
}

export default Component.extend(TextareaTextManipulation, {
  classNames: ["d-editor"],
  ready: false,
  lastSel: null,
  _itsatrap: null,
  showLink: true,
  emojiPickerIsActive: false,
  emojiStore: service("emoji-store"),
  isEditorFocused: false,
  processPreview: true,
  composerFocusSelector: "#reply-control .d-editor-input",

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
    this._applyCategoryHashtagAutocomplete(this._$textarea);

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

    this._itsatrap.bind("tab", () => this._indentSelection("right"));
    this._itsatrap.bind("shift+tab", () => this._indentSelection("left"));

    // disable clicking on links in the preview
    this.element
      .querySelector(".d-editor-preview")
      .addEventListener("click", this._handlePreviewLinkClick);

    if (this.composerEvents) {
      this.appEvents.on("composer:insert-block", this, "_insertBlock");
      this.appEvents.on("composer:insert-text", this, "_insertText");
      this.appEvents.on("composer:replace-text", this, "_replaceText");
      this.appEvents.on(
        "composer:indent-selected-text",
        this,
        "_indentSelection"
      );
    }

    if (isTesting()) {
      this.element.addEventListener("paste", this.paste);
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
      this.appEvents.off("composer:insert-block", this, "_insertBlock");
      this.appEvents.off("composer:insert-text", this, "_insertText");
      this.appEvents.off("composer:replace-text", this, "_replaceText");
      this.appEvents.off(
        "composer:indent-selected-text",
        this,
        "_indentSelection"
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
      this.getProperties("site", "siteSettings", "showLink")
    );
    toolbar.context = this;

    _createCallbacks.forEach((cb) => cb(toolbar));

    if (this.extraButtons) {
      this.extraButtons(toolbar);
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
          window.diff.innerHTML(
            this.element.querySelector(".d-editor-preview"),
            cookedElement.innerHTML
          );
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

  _applyCategoryHashtagAutocomplete() {
    const siteSettings = this.siteSettings;

    this._$textarea.autocomplete({
      template: findRawTemplate("category-tag-autocomplete"),
      key: "#",
      afterComplete: (value) => {
        this.set("value", value);
        schedule("afterRender", this, this._focusTextArea);
      },
      transformComplete: (obj) => {
        return obj.text;
      },
      dataSource: (term) => {
        if (term.match(/\s/)) {
          return null;
        }
        return searchCategoryTag(term, siteSettings);
      },
      triggerRule: (textarea, opts) => {
        return categoryHashtagTriggerRule(textarea, opts);
      },
    });
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
        schedule("afterRender", this, this._focusTextArea);
      },

      onKeyUp: (text, cp) => {
        if (inCodeBlock(text, cp)) {
          return false;
        }

        const matches = /(?:^|[\s.\?,@\/#!%&*;:\[\]{}=\-_()])(:(?!:).?[\w-]*:?(?!:)(?:t\d?)?:?) ?$/gi.exec(
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

          schedule("afterRender", () => {
            const filterInput = document.querySelector(
              ".emoji-picker input[name='filter']"
            );
            if (filterInput) {
              filterInput.value = v.term;

              later(() => filterInput.dispatchEvent(new Event("input")), 50);
            }
          });

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
              return resolve(this.emojiStore.favorites.slice(0, 5));
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
          const allTranslations = Object.assign(
            {},
            translations,
            this.getWithDefault("site.custom_emoji_translation", {})
          );
          if (allTranslations[full]) {
            return resolve([allTranslations[full]]);
          }

          const match = term.match(/^:?(.*?):t([2-6])?$/);
          if (match) {
            const name = match[1];
            const scale = match[2];

            if (isSkinTonableEmoji(name)) {
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
          });

          return resolve(options);
        })
          .then((list) =>
            list.map((code) => {
              return { code, src: emojiUrlFor(code) };
            })
          )
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

  // perform the same operation over many lines of text
  _getMultilineContents(lines, head, hval, hlen, tail, tlen, opts) {
    let operation = OP.NONE;

    const applyEmptyLines = opts && opts.applyEmptyLines;

    return lines
      .map((l) => {
        if (!applyEmptyLines && l.length === 0) {
          return l;
        }

        if (
          operation !== OP.ADDED &&
          ((l.slice(0, hlen) === hval && tlen === 0) ||
            (tail.length && l.slice(-tlen) === tail))
        ) {
          operation = OP.REMOVED;
          if (tlen === 0) {
            const result = l.slice(hlen);
            [hval, hlen] = getHead(head, hval);
            return result;
          } else if (l.slice(-tlen) === tail) {
            const result = l.slice(hlen, -tlen);
            [hval, hlen] = getHead(head, hval);
            return result;
          }
        } else if (operation === OP.NONE) {
          operation = OP.ADDED;
        } else if (operation === OP.REMOVED) {
          return l;
        }

        const result = `${hval}${l}${tail}`;
        [hval, hlen] = getHead(head, hval);
        return result;
      })
      .join("\n");
  },

  _applySurround(sel, head, tail, exampleKey, opts) {
    const pre = sel.pre;
    const post = sel.post;

    const tlen = tail.length;
    if (sel.start === sel.end) {
      if (tlen === 0) {
        return;
      }

      const [hval, hlen] = getHead(head);
      const example = I18n.t(`composer.${exampleKey}`);
      this.set("value", `${pre}${hval}${example}${tail}${post}`);
      this._selectText(pre.length + hlen, example.length);
    } else if (opts && !opts.multiline) {
      let [hval, hlen] = getHead(head);

      if (opts.useBlockMode && sel.value.split("\n").length > 1) {
        hval += "\n";
        hlen += 1;
        tail = `\n${tail}`;
      }

      if (pre.slice(-hlen) === hval && post.slice(0, tail.length) === tail) {
        this.set(
          "value",
          `${pre.slice(0, -hlen)}${sel.value}${post.slice(tail.length)}`
        );
        this._selectText(sel.start - hlen, sel.value.length);
      } else {
        this.set("value", `${pre}${hval}${sel.value}${tail}${post}`);
        this._selectText(sel.start + hlen, sel.value.length);
      }
    } else {
      const lines = sel.value.split("\n");

      let [hval, hlen] = getHead(head);
      if (
        lines.length === 1 &&
        pre.slice(-tlen) === tail &&
        post.slice(0, hlen) === hval
      ) {
        this.set(
          "value",
          `${pre.slice(0, -hlen)}${sel.value}${post.slice(tlen)}`
        );
        this._selectText(sel.start - hlen, sel.value.length);
      } else {
        const contents = this._getMultilineContents(
          lines,
          head,
          hval,
          hlen,
          tail,
          tlen,
          opts
        );

        this.set("value", `${pre}${contents}${post}`);
        if (lines.length === 1 && tlen > 0) {
          this._selectText(sel.start + hlen, sel.value.length);
        } else {
          this._selectText(sel.start, contents.length);
        }
      }
    }
  },

  _applyList(sel, head, exampleKey, opts) {
    if (sel.value.indexOf("\n") !== -1) {
      this._applySurround(sel, head, "", exampleKey, opts);
    } else {
      const [hval, hlen] = getHead(head);
      if (sel.start === sel.end) {
        sel.value = I18n.t(`composer.${exampleKey}`);
      }

      const trimmedPre = sel.pre.trim();
      const number =
        sel.value.indexOf(hval) === 0
          ? sel.value.slice(hlen)
          : `${hval}${sel.value}`;
      const preLines = trimmedPre.length ? `${trimmedPre}\n\n` : "";

      const trimmedPost = sel.post.trim();
      const post = trimmedPost.length ? `\n\n${trimmedPost}` : trimmedPost;

      this.set("value", `${preLines}${number}${post}`);
      this._selectText(preLines.length, number.length);
    }
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

      const selected = this._getSelected(button.trimLeading);
      const toolbarEvent = {
        selected,
        selectText: (from, length) =>
          this._selectText(from, length, { scroll: false }),
        applySurround: (head, tail, exampleKey, opts) =>
          this._applySurround(selected, head, tail, exampleKey, opts),
        applyList: (head, exampleKey, opts) =>
          this._applyList(selected, head, exampleKey, opts),
        addText: (text) => this._addText(selected, text),
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

      const sel = this._getSelected("", { lineVal: true });
      const selValue = sel.value;
      const hasNewLine = selValue.indexOf("\n") !== -1;
      const isBlankLine = sel.lineVal.trim().length === 0;
      const isFourSpacesIndent =
        this.siteSettings.code_formatting_style === FOUR_SPACES_INDENT;

      if (!hasNewLine) {
        if (selValue.length === 0 && isBlankLine) {
          if (isFourSpacesIndent) {
            const example = I18n.t(`composer.code_text`);
            this.set("value", `${sel.pre}    ${example}${sel.post}`);
            return this._selectText(sel.pre.length + 4, example.length);
          } else {
            return this._applySurround(
              sel,
              "```\n",
              "\n```",
              "paste_code_text"
            );
          }
        } else {
          return this._applySurround(sel, "`", "`", "code_title");
        }
      } else {
        if (isFourSpacesIndent) {
          return this._applySurround(sel, "    ", "", "code_text");
        } else {
          const preNewline = sel.pre[-1] !== "\n" && sel.pre !== "" ? "\n" : "";
          const postNewline = sel.post[0] !== "\n" ? "\n" : "";
          return this._addText(
            sel,
            `${preNewline}\`\`\`\n${sel.value}\n\`\`\`${postNewline}`
          );
        }
      }
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
