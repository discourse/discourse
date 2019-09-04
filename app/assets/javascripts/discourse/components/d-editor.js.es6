/*global Mousetrap:true */
import {
  default as computed,
  on,
  observes
} from "ember-addons/ember-computed-decorators";
import { categoryHashtagTriggerRule } from "discourse/lib/category-hashtags";
import { search as searchCategoryTag } from "discourse/lib/category-tag-search";
import { cookAsync } from "discourse/lib/text";
import { getRegister } from "discourse-common/lib/get-owner";
import { findRawTemplate } from "discourse/lib/raw-templates";
import { siteDir } from "discourse/lib/text-direction";
import {
  determinePostReplaceSelection,
  clipboardData,
  safariHacksDisabled
} from "discourse/lib/utilities";
import toMarkdown from "discourse/lib/to-markdown";
import deprecated from "discourse-common/lib/deprecated";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { translations } from "pretty-text/emoji/data";
import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { emojiUrlFor } from "discourse/lib/text";

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
  ADDED: 2
};

const FOUR_SPACES_INDENT = "4-spaces-indent";

const _createCallbacks = [];

const isInside = (text, regex) => {
  const matches = text.match(regex);
  return matches && matches.length % 2;
};

class Toolbar {
  constructor(opts) {
    const { siteSettings } = opts;
    this.shortcuts = {};
    this.context = null;

    this.groups = [
      { group: "fontStyles", buttons: [] },
      { group: "insertions", buttons: [] },
      { group: "extras", buttons: [] }
    ];

    this.addButton({
      trimLeading: true,
      id: "bold",
      group: "fontStyles",
      icon: "bold",
      label: getButtonLabel("composer.bold_label", "B"),
      shortcut: "B",
      perform: e => e.applySurround("**", "**", "bold_text")
    });

    this.addButton({
      trimLeading: true,
      id: "italic",
      group: "fontStyles",
      icon: "italic",
      label: getButtonLabel("composer.italic_label", "I"),
      shortcut: "I",
      perform: e => e.applySurround("*", "*", "italic_text")
    });

    if (opts.showLink) {
      this.addButton({
        id: "link",
        group: "insertions",
        shortcut: "K",
        action: (...args) => this.context.send("showLinkModal", args)
      });
    }

    this.addButton({
      id: "quote",
      group: "insertions",
      icon: "quote-right",
      shortcut: "Shift+9",
      perform: e =>
        e.applyList("> ", "blockquote_text", {
          applyEmptyLines: true,
          multiline: true
        })
    });

    this.addButton({
      id: "code",
      group: "insertions",
      shortcut: "Shift+C",
      action: (...args) => this.context.send("formatCode", args)
    });

    this.addButton({
      id: "bullet",
      group: "extras",
      icon: "list-ul",
      shortcut: "Shift+8",
      title: "composer.ulist_title",
      perform: e => e.applyList("* ", "list_item")
    });

    this.addButton({
      id: "list",
      group: "extras",
      icon: "list-ol",
      shortcut: "Shift+7",
      title: "composer.olist_title",
      perform: e =>
        e.applyList(i => (!i ? "1. " : `${parseInt(i) + 1}. `), "list_item")
    });

    if (siteSettings.support_mixed_text_direction) {
      this.addButton({
        id: "toggle-direction",
        group: "extras",
        icon: "exchange-alt",
        shortcut: "Shift+6",
        title: "composer.toggle_direction",
        perform: e => e.toggleDirection()
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
      className: button.className || button.id,
      label: button.label,
      icon: button.label ? null : button.icon || button.id,
      action: button.action || (a => this.context.send("toolbarButton", a)),
      perform: button.perform || function() {},
      trimLeading: button.trimLeading,
      popupMenu: button.popupMenu || false
    };

    if (button.sendAction) {
      createdButton.sendAction = button.sendAction;
    }

    const title = I18n.t(button.title || `composer.${button.id}_title`);
    if (button.shortcut) {
      const mac = /Mac|iPod|iPhone|iPad/.test(navigator.platform);
      const mod = mac ? "Meta" : "Ctrl";
      var shortcutTitle = `${mod}+${button.shortcut}`;

      // Mac users are used to glyphs for shortcut keys
      if (mac) {
        shortcutTitle = shortcutTitle
          .replace("Shift", "\u21E7")
          .replace("Meta", "\u2318")
          .replace("Alt", "\u2325")
          .replace(/\+/g, "");
      } else {
        shortcutTitle = shortcutTitle
          .replace("Shift", I18n.t("shortcut_modifier_key.shift"))
          .replace("Ctrl", I18n.t("shortcut_modifier_key.ctrl"))
          .replace("Alt", I18n.t("shortcut_modifier_key.alt"));
      }

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

export function onToolbarCreate(func) {
  deprecated("`onToolbarCreate` is deprecated, use the plugin api instead.");
  addToolbarCallback(func);
}

export default Ember.Component.extend({
  classNames: ["d-editor"],
  ready: false,
  insertLinkHidden: true,
  linkUrl: "",
  linkText: "",
  lastSel: null,
  _mouseTrap: null,
  showLink: true,
  emojiPickerIsActive: false,
  emojiStore: Ember.inject.service("emoji-store"),

  @computed("placeholder")
  placeholderTranslated(placeholder) {
    if (placeholder) return I18n.t(placeholder);
    return null;
  },

  _readyNow() {
    this.set("ready", true);

    if (this.autofocus) {
      this.element.querySelector("textarea").focus();
    }
  },

  init() {
    this._super(...arguments);

    this.register = getRegister(this);
  },

  didInsertElement() {
    this._super(...arguments);

    const $editorInput = $(this.element.querySelector(".d-editor-input"));
    this._applyEmojiAutocomplete($editorInput);
    this._applyCategoryHashtagAutocomplete($editorInput);

    Ember.run.scheduleOnce("afterRender", this, this._readyNow);

    const mouseTrap = Mousetrap(this.element.querySelector(".d-editor-input"));
    const shortcuts = this.get("toolbar.shortcuts");

    Object.keys(shortcuts).forEach(sc => {
      const button = shortcuts[sc];
      mouseTrap.bind(sc, () => {
        button.action(button);
        return false;
      });
    });

    // disable clicking on links in the preview
    $(this.element.querySelector(".d-editor-preview")).on(
      "click.preview",
      e => {
        if (wantsNewWindow(e)) {
          return;
        }
        const $target = $(e.target);
        if ($target.is("a.mention")) {
          this.appEvents.trigger(
            "click.discourse-preview-user-card-mention",
            $target
          );
        }
        if ($target.is("a.mention-group")) {
          this.appEvents.trigger(
            "click.discourse-preview-group-card-mention-group",
            $target
          );
        }
        if ($target.is("a")) {
          e.preventDefault();
          return false;
        }
      }
    );

    if (this.composerEvents) {
      this.appEvents.on("composer:insert-block", this, "_insertBlock");
      this.appEvents.on("composer:insert-text", this, "_insertText");
      this.appEvents.on("composer:replace-text", this, "_replaceText");
    }
    this._mouseTrap = mouseTrap;
  },

  _insertBlock(text) {
    this._addBlock(this._getSelected(), text);
  },

  _insertText(text, options) {
    this._addText(this._getSelected(), text, options);
  },

  @on("willDestroyElement")
  _shutDown() {
    if (this.composerEvents) {
      this.appEvents.off("composer:insert-block", this, "_insertBlock");
      this.appEvents.off("composer:insert-text", this, "_insertText");
      this.appEvents.off("composer:replace-text", this, "_replaceText");
    }

    const mouseTrap = this._mouseTrap;
    Object.keys(this.get("toolbar.shortcuts")).forEach(sc =>
      mouseTrap.unbind(sc)
    );
    $(this.element.querySelector(".d-editor-preview")).off("click.preview");
  },

  @computed
  toolbar() {
    const toolbar = new Toolbar(
      this.getProperties("site", "siteSettings", "showLink")
    );
    toolbar.context = this;

    _createCallbacks.forEach(cb => cb(toolbar));

    if (this.extraButtons) {
      this.extraButtons(toolbar);
    }
    return toolbar;
  },

  _updatePreview() {
    if (this._state !== "inDOM") {
      return;
    }

    const value = this.value;
    const markdownOptions = this.markdownOptions || {};

    cookAsync(value, markdownOptions).then(cooked => {
      if (this.isDestroyed) {
        return;
      }
      this.set("preview", cooked);
      Ember.run.scheduleOnce("afterRender", () => {
        if (this._state !== "inDOM") {
          return;
        }
        const $preview = $(this.element.querySelector(".d-editor-preview"));
        if ($preview.length === 0) return;

        if (this.previewUpdated) {
          this.previewUpdated($preview);
        }
      });
    });
  },

  @observes("ready", "value")
  _watchForChanges() {
    if (!this.ready) {
      return;
    }

    // Debouncing in test mode is complicated
    if (Ember.testing) {
      this._updatePreview();
    } else {
      Ember.run.debounce(this, this._updatePreview, 30);
    }
  },

  _applyCategoryHashtagAutocomplete() {
    const siteSettings = this.siteSettings;

    $(this.element.querySelector(".d-editor-input")).autocomplete({
      template: findRawTemplate("category-tag-autocomplete"),
      key: "#",
      afterComplete: () => this._focusTextArea(),
      transformComplete: obj => {
        return obj.text;
      },
      dataSource: term => {
        if (term.match(/\s/)) {
          return null;
        }
        return searchCategoryTag(term, siteSettings);
      },
      triggerRule: (textarea, opts) => {
        return categoryHashtagTriggerRule(textarea, opts);
      }
    });
  },

  _applyEmojiAutocomplete($editorInput) {
    if (!this.siteSettings.enable_emoji) {
      return;
    }

    $editorInput.autocomplete({
      template: findRawTemplate("emoji-selector-autocomplete"),
      key: ":",
      afterComplete: text => {
        this.set("value", text);
        this._focusTextArea();
      },

      onKeyUp: (text, cp) => {
        const matches = /(?:^|[^a-z])(:(?!:).?[\w-]*:?(?!:)(?:t\d?)?:?) ?$/gi.exec(
          text.substring(0, cp)
        );

        if (matches && matches[1]) {
          return [matches[1]];
        }
      },

      transformComplete: v => {
        if (v.code) {
          this.emojiStore.track(v.code);
          return `${v.code}:`;
        } else {
          $editorInput.autocomplete({ cancel: true });
          this.setProperties({
            isEditorFocused: $("textarea.d-editor-input").is(":focus"),
            emojiPickerIsActive: true
          });

          Ember.run.schedule("afterRender", () => {
            const filterInput = document.querySelector(
              ".emoji-picker input[name='filter']"
            );
            if (filterInput) {
              filterInput.value = v.term;

              Ember.run.later(
                () => filterInput.dispatchEvent(new Event("input")),
                50
              );
            }
          });

          return "";
        }
      },

      dataSource: term => {
        return new Ember.RSVP.Promise(resolve => {
          const full = `:${term}`;
          term = term.toLowerCase();

          if (term.length < this.siteSettings.emoji_autocomplete_min_chars) {
            return resolve([]);
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
                "blush"
              ]);
            }
          }

          if (translations[full]) {
            return resolve([translations[full]]);
          }

          const match = term.match(/^:?(.*?):t([2-6])?$/);
          if (match) {
            const name = match[1];
            const scale = match[2];

            if (isSkinTonableEmoji(name)) {
              if (scale) {
                return resolve([`${name}:t${scale}`]);
              } else {
                return resolve([2, 3, 4, 5, 6].map(x => `${name}:t${x}`));
              }
            }
          }

          const options = emojiSearch(term, { maxResults: 5 });

          return resolve(options);
        })
          .then(list =>
            list.map(code => {
              return { code, src: emojiUrlFor(code) };
            })
          )
          .then(list => {
            if (list.length) {
              list.push({ label: I18n.t("composer.more_emoji"), term });
            }
            return list;
          });
      }
    });
  },

  _getSelected(trimLeading, opts) {
    if (!this.ready) {
      return;
    }

    const textarea = this.element.querySelector("textarea.d-editor-input");
    const value = textarea.value;
    let start = textarea.selectionStart;
    let end = textarea.selectionEnd;

    // trim trailing spaces cause **test ** would be invalid
    while (end > start && /\s/.test(value.charAt(end - 1))) {
      end--;
    }

    if (trimLeading) {
      // trim leading spaces cause ** test** would be invalid
      while (end > start && /\s/.test(value.charAt(start))) {
        start++;
      }
    }

    const selVal = value.substring(start, end);
    const pre = value.slice(0, start);
    const post = value.slice(end);

    if (opts && opts.lineVal) {
      const lineVal = value.split("\n")[
        value.substr(0, textarea.selectionStart).split("\n").length - 1
      ];
      return { start, end, value: selVal, pre, post, lineVal };
    } else {
      return { start, end, value: selVal, pre, post };
    }
  },

  _selectText(from, length) {
    Ember.run.scheduleOnce("afterRender", () => {
      const textarea = this.element.querySelector("textarea.d-editor-input");
      const $textarea = $(textarea);
      const oldScrollPos = $textarea.scrollTop();
      if (!this.capabilities.isIOS || safariHacksDisabled()) {
        $textarea.focus();
      }
      textarea.selectionStart = from;
      textarea.selectionEnd = from + length;
      Ember.run.next(() => $textarea.trigger("change"));
      $textarea.scrollTop(oldScrollPos);
    });
  },

  // perform the same operation over many lines of text
  _getMultilineContents(lines, head, hval, hlen, tail, tlen, opts) {
    let operation = OP.NONE;

    const applyEmptyLines = opts && opts.applyEmptyLines;

    return lines
      .map(l => {
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

  _replaceText(oldVal, newVal, opts = {}) {
    const val = this.value;
    const needleStart = val.indexOf(oldVal);

    if (needleStart === -1) {
      // Nothing to replace.
      return;
    }

    const textarea = this.element.querySelector("textarea.d-editor-input");

    // Determine post-replace selection.
    const newSelection = determinePostReplaceSelection({
      selection: { start: textarea.selectionStart, end: textarea.selectionEnd },
      needle: { start: needleStart, end: needleStart + oldVal.length },
      replacement: { start: needleStart, end: needleStart + newVal.length }
    });

    if (opts.index && opts.regex) {
      let i = -1;
      const newValue = val.replace(opts.regex, match => {
        i++;
        return i === opts.index ? newVal : match;
      });
      this.set("value", newValue);
    } else {
      // Replace value (side effect: cursor at the end).
      this.set("value", val.replace(oldVal, newVal));
    }

    if (opts.forceFocus || $("textarea.d-editor-input").is(":focus")) {
      // Restore cursor.
      this._selectText(
        newSelection.start,
        newSelection.end - newSelection.start
      );
    }
  },

  _addBlock(sel, text) {
    text = (text || "").trim();
    if (text.length === 0) {
      return;
    }

    let pre = sel.pre;
    let post = sel.value + sel.post;

    if (pre.length > 0) {
      pre = pre.replace(/\n*$/, "\n\n");
    }

    if (post.length > 0) {
      post = post.replace(/^\n*/, "\n\n");
    } else {
      post = "\n";
    }

    const value = pre + text + post;
    const $textarea = $(this.element.querySelector("textarea.d-editor-input"));

    this.set("value", value);

    $textarea.val(value);
    $textarea.prop("selectionStart", (pre + text).length + 2);
    $textarea.prop("selectionEnd", (pre + text).length + 2);

    this._focusTextArea();
  },

  _addText(sel, text, options) {
    const $textarea = $(this.element.querySelector("textarea.d-editor-input"));

    if (options && options.ensureSpace) {
      if ((sel.pre + "").length > 0) {
        if (!sel.pre.match(/\s$/)) {
          text = " " + text;
        }
      }
      if ((sel.post + "").length > 0) {
        if (!sel.post.match(/^\s/)) {
          text = text + " ";
        }
      }
    }

    const insert = `${sel.pre}${text}`;
    const value = `${insert}${sel.post}`;
    this.set("value", value);
    $textarea.val(value);
    $textarea.prop("selectionStart", insert.length);
    $textarea.prop("selectionEnd", insert.length);
    Ember.run.next(() => $textarea.trigger("change"));
    this._focusTextArea();
  },

  _extractTable(text) {
    if (text.endsWith("\n")) {
      text = text.substring(0, text.length - 1);
    }

    let rows = text.split("\n");

    if (rows.length > 1) {
      const columns = rows.map(r => r.split("\t").length);
      const isTable =
        columns.reduce((a, b) => a && columns[0] === b && b > 1) &&
        !(columns[0] === 2 && rows[0].split("\t")[0].match(/^•$|^\d+.$/)); // to skip tab delimited lists

      if (isTable) {
        const splitterRow = [...Array(columns[0])].map(() => "---").join("\t");
        rows.splice(1, 0, splitterRow);

        return (
          "|" + rows.map(r => r.split("\t").join("|")).join("|\n|") + "|\n"
        );
      }
    }
    return null;
  },

  _toggleDirection() {
    const $textArea = $(".d-editor-input");
    let currentDir = $textArea.attr("dir") ? $textArea.attr("dir") : siteDir(),
      newDir = currentDir === "ltr" ? "rtl" : "ltr";

    $textArea.attr("dir", newDir).focus();
  },

  paste(e) {
    if (!$(".d-editor-input").is(":focus")) {
      return;
    }

    const isComposer = $("#reply-control .d-editor-input").is(":focus");
    let { clipboard, canPasteHtml } = clipboardData(e, isComposer);

    let plainText = clipboard.getData("text/plain");
    let html = clipboard.getData("text/html");
    let handled = false;

    const { pre, lineVal } = this._getSelected(null, { lineVal: true });
    const isInlinePasting = pre.match(/[^\n]$/);
    const isCodeBlock = isInside(pre, /(^|\n)```/g);

    if (
      plainText &&
      this.siteSettings.enable_rich_text_paste &&
      !isInlinePasting &&
      !isCodeBlock
    ) {
      plainText = plainText.trim().replace(/\r/g, "");
      const table = this._extractTable(plainText);
      if (table) {
        this.appEvents.trigger("composer:insert-text", table);
        handled = true;
      }
    }

    if (canPasteHtml && plainText) {
      if (isInlinePasting) {
        canPasteHtml = !(
          lineVal.match(/^```/) ||
          isInside(pre, /`/g) ||
          lineVal.match(/^    /)
        );
      } else {
        canPasteHtml = !isCodeBlock;
      }
    }

    if (canPasteHtml && !handled) {
      let markdown = toMarkdown(html);

      if (!plainText || plainText.length < markdown.length) {
        if (isInlinePasting) {
          markdown = markdown.replace(/^#+/, "").trim();
          markdown = pre.match(/\S$/) ? ` ${markdown}` : markdown;
        }

        this.appEvents.trigger("composer:insert-text", markdown);
        handled = true;
      }
    }

    if (handled) {
      e.preventDefault();
    }
  },

  // ensures textarea scroll position is correct
  _focusTextArea() {
    const textarea = this.element.querySelector("textarea.d-editor-input");
    Ember.run.scheduleOnce("afterRender", () => {
      textarea.blur();
      textarea.focus();
    });
  },

  actions: {
    emoji() {
      if (this.disabled) {
        return;
      }

      this.set("isEditorFocused", $("textarea.d-editor-input").is(":focus"));
      this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
    },

    emojiSelected(code) {
      let selected = this._getSelected();
      const captures = selected.pre.match(/\B:(\w*)$/);

      if (_.isEmpty(captures)) {
        this._addText(selected, `:${code}:`);
      } else {
        let numOfRemovedChars = selected.pre.length - captures[1].length;
        selected.pre = selected.pre.slice(
          0,
          selected.pre.length - captures[1].length
        );
        selected.start -= numOfRemovedChars;
        selected.end -= numOfRemovedChars;
        this._addText(selected, `${code}:`);
      }
    },

    toolbarButton(button) {
      if (this.disabled) {
        return;
      }

      const selected = this._getSelected(button.trimLeading);
      const toolbarEvent = {
        selected,
        selectText: (from, length) => this._selectText(from, length),
        applySurround: (head, tail, exampleKey, opts) =>
          this._applySurround(selected, head, tail, exampleKey, opts),
        applyList: (head, exampleKey, opts) =>
          this._applyList(selected, head, exampleKey, opts),
        addText: text => this._addText(selected, text),
        replaceText: text => this._addText({ pre: "", post: "" }, text),
        getText: () => this.value,
        toggleDirection: () => this._toggleDirection()
      };

      if (button.sendAction) {
        return button.sendAction(toolbarEvent);
      } else {
        button.perform(toolbarEvent);
      }
    },

    showLinkModal() {
      if (this.disabled) {
        return;
      }

      this.set("linkUrl", "");
      this.set("linkText", "");

      this._lastSel = this._getSelected();

      if (this._lastSel) {
        this.set("linkText", this._lastSel.value.trim());
      }

      this.set("insertLinkHidden", false);
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

    insertLink() {
      const origLink = this.linkUrl;
      const linkUrl =
        origLink.indexOf("://") === -1 ? `http://${origLink}` : origLink;
      const sel = this._lastSel;

      if (Ember.isEmpty(linkUrl)) {
        return;
      }

      const linkText = this.linkText || "";
      if (linkText.length) {
        this._addText(sel, `[${linkText}](${linkUrl})`);
      } else {
        if (sel.value) {
          this._addText(sel, `[${sel.value}](${linkUrl})`);
        } else {
          this._addText(sel, `[${origLink}](${linkUrl})`);
          this._selectText(sel.start + 1, origLink.length);
        }
      }
    }
  }
});
