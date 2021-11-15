import { bind } from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";
import toMarkdown from "discourse/lib/to-markdown";
import { isTesting } from "discourse-common/config/environment";
import {
  clipboardHelpers,
  determinePostReplaceSelection,
  safariHacksDisabled,
} from "discourse/lib/utilities";
import { next, schedule } from "@ember/runloop";

const isInside = (text, regex) => {
  const matches = text.match(regex);
  return matches && matches.length % 2;
};

export default Mixin.create({
  // ensures textarea scroll position is correct
  _focusTextArea() {
    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      if (!this._textarea) {
        return;
      }

      this._textarea.blur();
      this._textarea.focus();
    });
  },

  _insertBlock(text) {
    this._addBlock(this._getSelected(), text);
  },

  _insertText(text, options) {
    this._addText(this._getSelected(), text, options);
  },

  _getSelected(trimLeading, opts) {
    if (!this.ready || !this.element) {
      return;
    }

    const value = this._textarea.value;
    let start = this._textarea.selectionStart;
    let end = this._textarea.selectionEnd;

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
        value.substr(0, this._textarea.selectionStart).split("\n").length - 1
      ];
      return { start, end, value: selVal, pre, post, lineVal };
    } else {
      return { start, end, value: selVal, pre, post };
    }
  },

  _selectText(from, length, opts = { scroll: true }) {
    next(() => {
      if (!this.element) {
        return;
      }

      this._textarea.selectionStart = from;
      this._textarea.selectionEnd = from + length;
      this._$textarea.trigger("change");
      if (opts.scroll) {
        const oldScrollPos = this._$textarea.scrollTop();
        if (!this.capabilities.isIOS || safariHacksDisabled()) {
          this._$textarea.focus();
        }
        this._$textarea.scrollTop(oldScrollPos);
      }
    });
  },

  _replaceText(oldVal, newVal, opts = {}) {
    const val = this.value;
    const needleStart = val.indexOf(oldVal);

    if (needleStart === -1) {
      // Nothing to replace.
      return;
    }

    // Determine post-replace selection.
    const newSelection = determinePostReplaceSelection({
      selection: {
        start: this._textarea.selectionStart,
        end: this._textarea.selectionEnd,
      },
      needle: { start: needleStart, end: needleStart + oldVal.length },
      replacement: { start: needleStart, end: needleStart + newVal.length },
    });

    if (opts.index && opts.regex) {
      let i = -1;
      const newValue = val.replace(opts.regex, (match) => {
        i++;
        return i === opts.index ? newVal : match;
      });
      this.set("value", newValue);
    } else {
      // Replace value (side effect: cursor at the end).
      this.set("value", val.replace(oldVal, newVal));
    }

    if (opts.forceFocus || this._$textarea.is(":focus")) {
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

    this.set("value", value);

    this._$textarea.val(value);
    this._$textarea.prop("selectionStart", (pre + text).length + 2);
    this._$textarea.prop("selectionEnd", (pre + text).length + 2);

    this._focusTextArea();
  },

  _addText(sel, text, options) {
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
    this._$textarea.val(value);
    this._$textarea.prop("selectionStart", insert.length);
    this._$textarea.prop("selectionEnd", insert.length);
    next(() => this._$textarea.trigger("change"));
    this._focusTextArea();
  },

  _extractTable(text) {
    if (text.endsWith("\n")) {
      text = text.substring(0, text.length - 1);
    }

    text = text.split("");
    let cell = false;
    text.forEach((char, index) => {
      if (char === "\n" && cell) {
        text[index] = "\r";
      }
      if (char === '"') {
        text[index] = "";
        cell = !cell;
      }
    });

    let rows = text.join("").replace(/\r/g, "<br>").split("\n");

    if (rows.length > 1) {
      const columns = rows.map((r) => r.split("\t").length);
      const isTable =
        columns.reduce((a, b) => a && columns[0] === b && b > 1) &&
        !(columns[0] === 2 && rows[0].split("\t")[0].match(/^•$|^\d+.$/)); // to skip tab delimited lists

      if (isTable) {
        const splitterRow = [...Array(columns[0])].map(() => "---").join("\t");
        rows.splice(1, 0, splitterRow);

        return (
          "|" + rows.map((r) => r.split("\t").join("|")).join("|\n|") + "|\n"
        );
      }
    }
    return null;
  },

  @bind
  paste(e) {
    if (!this._$textarea.is(":focus") && !isTesting()) {
      return;
    }

    const isComposer = $(this.composerFocusSelector).is(":focus");
    let { clipboard, canPasteHtml, canUpload } = clipboardHelpers(e, {
      siteSettings: this.siteSettings,
      canUpload: isComposer,
    });

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
      plainText = plainText.replace(/\r/g, "");
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

    if (handled || (canUpload && !plainText)) {
      e.preventDefault();
    }
  },
});
