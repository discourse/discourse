import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";
import Mixin from "@ember/object/mixin";
import { generateLinkifyFunction } from "discourse/lib/text";
import toMarkdown from "discourse/lib/to-markdown";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { isTesting } from "discourse-common/config/environment";
import {
  clipboardHelpers,
  determinePostReplaceSelection,
} from "discourse/lib/utilities";
import { next, schedule } from "@ember/runloop";

const INDENT_DIRECTION_LEFT = "left";
const INDENT_DIRECTION_RIGHT = "right";

const OP = {
  NONE: 0,
  REMOVED: 1,
  ADDED: 2,
};

// Our head can be a static string or a function that returns a string
// based on input (like for numbered lists).
export function getHead(head, prev) {
  if (typeof head === "string") {
    return [head, head.length];
  } else {
    return getHead(head(prev));
  }
}

export default Mixin.create({
  init() {
    this._super(...arguments);
    generateLinkifyFunction(this.markdownOptions || {}).then((linkify) => {
      // When pasting links, we should use the same rules to match links as we do when creating links for a cooked post.
      this._cachedLinkify = linkify;
    });
  },

  // ensures textarea scroll position is correct
  //
  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  focusTextArea() {
    this._focusTextArea();
  },

  _focusTextArea() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (!this._textarea) {
      return;
    }

    this._textarea.blur();
    this._textarea.focus();
  },

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  insertBlock(text) {
    this._insertBlock(text);
  },

  _insertBlock(text) {
    this._addBlock(this.getSelected(), text);
  },

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  insertText(text, options) {
    this._insertText(text, options);
  },

  _insertText(text, options) {
    this._addText(this.getSelected(), text, options);
  },

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  getSelected(trimLeading, opts) {
    return this._getSelected(trimLeading, opts);
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

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  selectText(from, length, opts = { scroll: true }) {
    this._selectText(from, length, opts);
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
        if (!this.capabilities.isIOS) {
          this._$textarea.focus();
        }
        this._$textarea.scrollTop(oldScrollPos);
      }
    });
  },

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  replaceText(oldVal, newVal, opts = {}) {
    this._replaceText(oldVal, newVal, opts);
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

    if (
      (opts.forceFocus || this._$textarea.is(":focus")) &&
      !opts.skipNewSelection
    ) {
      // Restore cursor.
      this.selectText(
        newSelection.start,
        newSelection.end - newSelection.start
      );
    }
  },

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  applySurround(sel, head, tail, exampleKey, opts) {
    this._applySurround(sel, head, tail, exampleKey, opts);
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
      this.selectText(pre.length + hlen, example.length);
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
        this.selectText(sel.start - hlen, sel.value.length);
      } else {
        this.set("value", `${pre}${hval}${sel.value}${tail}${post}`);
        this.selectText(sel.start + hlen, sel.value.length);
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
        this.selectText(sel.start - hlen, sel.value.length);
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
          this.selectText(sel.start + hlen, sel.value.length);
        } else {
          this.selectText(sel.start, contents.length);
        }
      }
    }
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

    schedule("afterRender", this, this._focusTextArea);
  },

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  addText(sel, text, options) {
    this._addText(sel, text, options);
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

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  extractTable(text) {
    return this._extractTable(text);
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

  // TODO (martin) clean up this indirection, functions used outside this
  // file should not be prefixed with lowercase
  isInside(text, regex) {
    return this._isInside(text, regex);
  },

  _isInside(text, regex) {
    const matches = text.match(regex);
    return matches && matches.length % 2;
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

    const selected = this.getSelected(null, { lineVal: true });
    const { pre, value: selectedValue, lineVal } = selected;
    const isInlinePasting = pre.match(/[^\n]$/);
    const isCodeBlock = this._isInside(pre, /(^|\n)```/g);

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
          this._isInside(pre, /`/g) ||
          lineVal.match(/^    /)
        );
      } else {
        canPasteHtml = !isCodeBlock;
      }
    }

    if (
      this._cachedLinkify &&
      plainText &&
      !handled &&
      selected.end > selected.start &&
      // text selection does not contain url
      !this._cachedLinkify.test(selectedValue) &&
      // text selection does not contain a bbcode-like tag
      !selectedValue.match(/\[\/?[a-z =]+?\]/g)
    ) {
      if (this._cachedLinkify.test(plainText)) {
        const match = this._cachedLinkify.match(plainText)[0];
        if (
          match &&
          match.index === 0 &&
          match.lastIndex === match.raw.length
        ) {
          // When specified, linkify supports fuzzy links and emails. Prefer providing the protocol.
          // eg: pasting "example@discourse.org" may apply a link format of "mailto:example@discourse.org"
          this._addText(selected, `[${selectedValue}](${match.url})`);
          handled = true;
        }
      }
    }

    if (canPasteHtml && !handled) {
      let markdown = toMarkdown(html);

      if (!plainText || plainText.length < markdown.length) {
        if (isInlinePasting) {
          markdown = markdown.replace(/^#+/, "").trim();
          markdown = pre.match(/\S$/) ? ` ${markdown}` : markdown;
        }

        if (isComposer) {
          this.appEvents.trigger("composer:insert-text", markdown);
          handled = true;
        }
      }
    }

    if (handled || (canUpload && !plainText)) {
      e.preventDefault();
    }
  },

  /**
   * Removes the provided char from the provided str up
   * until the limit, or until a character that is _not_
   * the provided one is encountered.
   */
  _deindentLine(str, char, limit) {
    let eaten = 0;
    for (let i = 0; i < str.length; i++) {
      if (eaten < limit && str[i] === char) {
        eaten += 1;
      } else {
        return str.slice(eaten);
      }
    }
    return str;
  },

  @bind
  indentSelection(direction) {
    if (![INDENT_DIRECTION_LEFT, INDENT_DIRECTION_RIGHT].includes(direction)) {
      return;
    }

    const selected = this.getSelected(null, { lineVal: true });
    const { lineVal } = selected;
    let value = selected.value;

    // Perhaps this is a bit simplistic, but it is a fairly reliable
    // guess to say whether we are indenting with tabs or spaces. for
    // example some programming languages prefer tabs, others prefer
    // spaces, and for the cases with no tabs it's safer to use spaces
    let indentationSteps, indentationChar;
    let linesStartingWithTabCount = value.match(/^\t/gm)?.length || 0;
    let linesStartingWithSpaceCount = value.match(/^ /gm)?.length || 0;
    if (linesStartingWithTabCount > linesStartingWithSpaceCount) {
      indentationSteps = 1;
      indentationChar = "\t";
    } else {
      indentationChar = " ";
      indentationSteps = 2;
    }

    // We want to include all the spaces on the selected line as
    // well, no matter where the cursor begins on the first line,
    // because we want to indent those too. * is the cursor/selection
    // and . are spaces:
    //
    // BEFORE               AFTER
    //
    //     *                *
    // ....text here        ....text here
    // ....some more text   ....some more text
    //                  *                    *
    //
    // BEFORE               AFTER
    //
    //  *                   *
    // ....text here        ....text here
    // ....some more text   ....some more text
    //                  *                    *
    const indentationRegexp = new RegExp(`^${indentationChar}+`);
    const lineStartsWithIndentationChar = lineVal.match(indentationRegexp);
    const intentationCharsBeforeSelection = value.match(indentationRegexp);
    if (lineStartsWithIndentationChar) {
      const charsToSubtract = intentationCharsBeforeSelection
        ? intentationCharsBeforeSelection[0]
        : "";
      value =
        lineStartsWithIndentationChar[0].replace(charsToSubtract, "") + value;
    }

    const splitSelection = value.split("\n");
    const newValue = splitSelection
      .map((line) => {
        if (direction === INDENT_DIRECTION_LEFT) {
          return this._deindentLine(line, indentationChar, indentationSteps);
        } else {
          return `${Array(indentationSteps + 1).join(indentationChar)}${line}`;
        }
      })
      .join("\n");

    if (newValue.trim() !== "") {
      this.replaceText(value, newValue, { skipNewSelection: true });
      this.selectText(this.value.indexOf(newValue), newValue.length);
    }
  },

  @action
  emojiSelected(code) {
    let selected = this.getSelected();
    const captures = selected.pre.match(/\B:(\w*)$/);

    if (isEmpty(captures)) {
      if (selected.pre.match(/\S$/)) {
        this._addText(selected, ` :${code}:`);
      } else {
        this._addText(selected, `:${code}:`);
      }
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
});
