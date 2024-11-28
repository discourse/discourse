import { setOwner } from "@ember/owner";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import $ from "jquery";
import putCursorAtEnd from "discourse/lib/put-cursor-at-end";
import { generateLinkifyFunction } from "discourse/lib/text";
import { siteDir } from "discourse/lib/text-direction";
import toMarkdown from "discourse/lib/to-markdown";
import {
  caretPosition,
  clipboardHelpers,
  determinePostReplaceSelection,
  inCodeBlock,
} from "discourse/lib/utilities";
import { isTesting } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

const INDENT_DIRECTION_LEFT = "left";
const INDENT_DIRECTION_RIGHT = "right";

// Supports '- ', '* ', '1. ', '- [ ]', '- [x]', `* [ ] `, `* [x] `, '1. [ ] ', '1. [x] '
const LIST_REGEXP = /^(\s*)([*-]|(\d+)\.)\s(\[[\sx]\]\s)?/;

const OP = {
  NONE: 0,
  REMOVED: 1,
  ADDED: 2,
};

const FOUR_SPACES_INDENT = "4-spaces-indent";

// Our head can be a static string or a function that returns a string
// based on input (like for numbered lists).
export function getHead(head, prev) {
  if (typeof head === "string") {
    return [head, head.length];
  } else {
    return getHead(head(prev));
  }
}

export default class TextareaTextManipulation {
  @service appEvents;
  @service siteSettings;
  @service capabilities;
  @service currentUser;

  eventPrefix;
  textarea;
  $textarea;

  constructor(owner, { markdownOptions, textarea, eventPrefix = "composer" }) {
    setOwner(this, owner);

    this.eventPrefix = eventPrefix;
    this.textarea = textarea;
    this.$textarea = $(textarea);

    generateLinkifyFunction(markdownOptions || {}).then((linkify) => {
      // When pasting links, we should use the same rules to match links as we do when creating links for a cooked post.
      this._cachedLinkify = linkify;
    });
  }

  get value() {
    return this.textarea.value;
  }

  set value(value) {
    this.textarea.value = value;
    this.textarea.dispatchEvent(new Event("change", { bubbles: true }));
  }

  // ensures textarea scroll position is correct
  blurAndFocus() {
    this.textarea?.blur();
    this.textarea?.focus();
  }

  focus() {
    this.textarea.focus();
  }

  insertBlock(text) {
    this._addBlock(this.getSelected(), text);
  }

  insertText(text, options) {
    this.addText(this.getSelected(), text, options);
  }

  getSelected(trimLeading, opts) {
    const value = this.value;
    let start = this.textarea.selectionStart;
    let end = this.textarea.selectionEnd;

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
      const lineVal =
        value.split("\n")[
          value.slice(0, this.textarea.selectionStart).split("\n").length - 1
        ];
      return { start, end, value: selVal, pre, post, lineVal };
    } else {
      return { start, end, value: selVal, pre, post };
    }
  }

  selectText(from, length, opts = { scroll: true }) {
    next(() => {
      this.textarea.selectionStart = from;
      this.textarea.selectionEnd = from + length;
      if (opts.scroll === true || typeof opts.scroll === "number") {
        const oldScrollPos =
          typeof opts.scroll === "number"
            ? opts.scroll
            : this.textarea.scrollTop;
        if (!this.capabilities.isIOS) {
          this.textarea.focus();
        }
        this.textarea.scrollTop = oldScrollPos;
      }
    });
  }

  replaceText(oldVal, newVal, opts = {}) {
    const val = this.value;
    const needleStart = val.indexOf(oldVal);

    if (needleStart === -1) {
      // Nothing to replace.
      return;
    }

    // Determine post-replace selection.
    const newSelection = determinePostReplaceSelection({
      selection: {
        start: this.textarea.selectionStart,
        end: this.textarea.selectionEnd,
      },
      needle: { start: needleStart, end: needleStart + oldVal.length },
      replacement: { start: needleStart, end: needleStart + newVal.length },
    });

    if (opts.index && opts.regex) {
      if (!opts.regex.global) {
        throw new Error("Regex must be global");
      }

      const regex = new RegExp(opts.regex);
      let match;
      for (let i = 0; i <= opts.index; i++) {
        match = regex.exec(val);
      }

      if (match) {
        this._insertAt(match.index, match.index + match[0].length, newVal);
      }
    } else {
      this._insertAt(needleStart, needleStart + oldVal.length, newVal);
    }

    if (
      (opts.forceFocus || this.textarea === document.activeElement) &&
      !opts.skipNewSelection
    ) {
      // Restore cursor.
      this.selectText(
        newSelection.start,
        newSelection.end - newSelection.start
      );
    }
  }

  applySurround(sel, head, tail, exampleKey, opts) {
    const pre = sel.pre;
    const post = sel.post;

    const tlen = tail.length;
    if (sel.start === sel.end) {
      if (tlen === 0) {
        return;
      }

      const [hval, hlen] = getHead(head);
      const example = i18n(`composer.${exampleKey}`);
      this._insertAt(sel.start, sel.end, `${hval}${example}${tail}`);
      this.selectText(pre.length + hlen, example.length);
    } else if (opts && !opts.multiline) {
      let [hval, hlen] = getHead(head);

      if (opts.useBlockMode && sel.value.split("\n").length > 1) {
        hval += "\n";
        hlen += 1;
        tail = `\n${tail}`;
      }

      if (pre.slice(-hlen) === hval && post.slice(0, tail.length) === tail) {
        // Already wrapped in the surround. Remove it.
        this._insertAt(sel.start - hlen, sel.end + tail.length, sel.value);
        this.selectText(sel.start - hlen, sel.value.length);
      } else {
        this._insertAt(sel.start, sel.end, `${hval}${sel.value}${tail}`);
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
        // Already wrapped in the surround. Remove it.
        this._insertAt(sel.start - hlen, sel.end + tlen, sel.value);
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

        this._insertAt(sel.start, sel.end, contents);
        if (lines.length === 1 && tlen > 0) {
          this.selectText(sel.start + hlen, sel.value.length);
        } else {
          this.selectText(sel.start, contents.length);
        }
      }
    }
  }

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
  }

  _addBlock(sel, text) {
    text = (text || "").trim();
    if (text.length === 0) {
      return;
    }

    let start = sel.start;
    let end = sel.end;

    const newLinesBeforeSelection = sel.pre?.match(/\n*$/)?.[0]?.length;
    if (newLinesBeforeSelection) {
      start -= newLinesBeforeSelection;
    }

    if (sel.pre.length > 0) {
      text = `\n\n${text}`;
    }

    const newLinesAfterSelection = sel.post?.match(/^\n*/)?.[0]?.length;
    if (newLinesAfterSelection) {
      end += newLinesAfterSelection;
    }

    if (sel.post.length > 0) {
      text = `${text}\n\n`;
    } else {
      text = `${text}\n`;
    }

    this._insertAt(start, end, text);
    this.textarea.setSelectionRange(start + text.length, start + text.length);
    schedule("afterRender", this, this.blurAndFocus);
  }

  addText(sel, text, options) {
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

    this._insertAt(sel.start, sel.end, text);
    this.blurAndFocus();
  }

  _insertAt(start, end, text) {
    this.textarea.setSelectionRange(start, end);
    this.textarea.focus();
    if (start !== end && text === "") {
      document.execCommand("delete", false);
    } else {
      document.execCommand("insertText", false, text);
    }
  }

  extractTable(text) {
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
  }

  isInside(text, regex) {
    const matches = text.match(regex);
    return matches && matches.length % 2;
  }

  @bind
  paste(e) {
    const isComposer = this.textarea === e.target;

    if (!isComposer && !isTesting()) {
      return;
    }

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
    const isCodeBlock = this.#isAfterStartedCodeFence(pre);

    if (
      plainText &&
      this.siteSettings.enable_rich_text_paste &&
      !isInlinePasting &&
      !isCodeBlock
    ) {
      plainText = plainText.replace(/\r/g, "");
      const table = this.extractTable(plainText);
      if (table) {
        this.eventPrefix
          ? this.appEvents.trigger(`${this.eventPrefix}:insert-text`, table)
          : this.insertText(table);
        handled = true;
      }
    }

    if (canPasteHtml && plainText) {
      if (isInlinePasting) {
        canPasteHtml = !(
          lineVal.match(/^```/) ||
          this.isInside(pre, /`/g) ||
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
          this.addText(selected, `[${selectedValue}](${match.url})`);
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
          this.eventPrefix
            ? this.appEvents.trigger(
                `${this.eventPrefix}:insert-text`,
                markdown
              )
            : this.insertText(markdown);
          handled = true;
        }
      }
    }

    if (handled || (canUpload && !plainText)) {
      e.preventDefault();
    }
  }

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
  }

  _updateListNumbers(text, currentNumber) {
    return text
      .split("\n")
      .map((line) => {
        if (line.replace(/^\s+/, "").startsWith(`${currentNumber}.`)) {
          const result = line.replace(
            `${currentNumber}`,
            `${currentNumber + 1}`
          );
          currentNumber += 1;
          return result;
        }
        return line;
      })
      .join("\n");
  }

  #isAfterStartedCodeFence(beforeText) {
    return this.isInside(beforeText, /(^|\n)```/g);
  }

  maybeContinueList() {
    const offset = caretPosition(this.textarea);
    const text = this.value;
    const lines = text.substring(0, offset).split("\n");

    // Only continue if the previous line was a list item.
    const previousLine = lines[lines.length - 2];
    const match = previousLine?.match(LIST_REGEXP);
    if (!match) {
      return;
    }

    if (this.#isAfterStartedCodeFence(text.substring(0, offset - 1))) {
      return;
    }

    const listPrefix = match[0];
    const indentationLevel = match[1];
    const bullet = match[2];
    const hasCheckbox = Boolean(match[4]);
    const numericBullet = parseInt(match[3], 10);
    const isNumericBullet = !isNaN(numericBullet);
    const newBullet = isNumericBullet ? `${numericBullet + 1}.` : bullet;
    let newPrefix = `${newBullet} ${hasCheckbox ? "[ ] " : ""}`;

    // Do not append list item if there already is one on this line.
    let currentLineEnd = text.indexOf("\n", offset);
    if (currentLineEnd < 0) {
      currentLineEnd = text.length;
    }
    const currentLine = text.substring(offset, currentLineEnd);
    if (currentLine.startsWith(newPrefix)) {
      newPrefix = "";
    }

    /*
      Autocomplete list element on next line if current line has list element containing text.
      or there's text on the line after the cursor (|):

      - | some text

      Becomes:

      -
      - | some text

      And

      - some text|

      Becomes:

      - some text
      - |
    */
    const shouldAutocomplete =
      previousLine.replace(listPrefix, "").trim().length > 0 ||
      currentLine.trim().length > 0;

    if (shouldAutocomplete) {
      let autocompletePrefix = `${indentationLevel}${newPrefix}`;
      let autocompletePostfix = text.substring(offset);
      const autocompletePrefixLength = autocompletePrefix.length;
      let scrollPosition;

      /*
        For numeric items, we have to also replace the rest of the
        numbered items in the list with their new values. Cursor is |.

        1. foo|
        2. bar

        Becomes

        1. foo
        2.
        3. bar
      */
      if (isNumericBullet && !text.substring(offset).match(/^\s*$/g)) {
        autocompletePostfix = this._updateListNumbers(
          text.substring(offset),
          numericBullet + 1
        );
        autocompletePrefix += autocompletePostfix;
        scrollPosition = this.textarea.scrollTop;

        this.replaceText(
          text.substring(offset, offset + autocompletePrefix.length),
          autocompletePrefix,
          {
            skipNewSelection: true,
          }
        );
      } else {
        this._insertAt(offset, offset, autocompletePrefix);
      }

      this.selectText(offset + autocompletePrefixLength, 0, {
        scroll: scrollPosition,
      });
    } else {
      // Clear the new autocompleted list item if there is no other text.
      const offsetWithoutPrefix = offset - `\n${listPrefix}`.length;
      this._insertAt(offsetWithoutPrefix, offset, "");
      this.selectText(offsetWithoutPrefix, 0);
    }
  }

  indentSelection(direction) {
    if (![INDENT_DIRECTION_LEFT, INDENT_DIRECTION_RIGHT].includes(direction)) {
      return;
    }

    const selected = this.getSelected(null, { lineVal: true });
    const { lineVal } = selected;
    let value = selected.value;

    /*
      Perhaps this is a bit simplistic, but it is a fairly reliable
      guess to say whether we are indenting with tabs or spaces. for
      example some programming languages prefer tabs, others prefer
      spaces, and for the cases with no tabs it's safer to use spaces
    */
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

    /*
      We want to include all the spaces on the selected line as
      well, no matter where the cursor begins on the first line,
      because we want to indent those too. * is the cursor/selection
      and . are spaces:

      BEFORE               AFTER

          *                *
      ....text here        ....text here
      ....some more text   ....some more text
                       *                    *

      BEFORE               AFTER

       *                   *
      ....text here        ....text here
      ....some more text   ....some more text
                       *                    *
    */
    const indentationRegexp = new RegExp(`^${indentationChar}+`);
    const lineStartsWithIndentationChar = lineVal.match(indentationRegexp);
    const indentationCharsBeforeSelection = value.match(indentationRegexp);
    if (lineStartsWithIndentationChar) {
      const charsToSubtract = indentationCharsBeforeSelection
        ? indentationCharsBeforeSelection[0]
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
  }

  @bind
  emojiSelected(code) {
    let selected = this.getSelected();
    const captures = selected.pre.match(/\B:(\w*)$/);

    if (isEmpty(captures)) {
      if (selected.pre.match(/\S$/)) {
        this.addText(selected, ` :${code}:`);
      } else {
        this.addText(selected, `:${code}:`);
      }
    } else {
      let numOfRemovedChars = captures[1].length;
      this._insertAt(
        selected.start - numOfRemovedChars,
        selected.end,
        `${code}:`
      );
    }
  }

  @bind
  async inCodeBlock() {
    return inCodeBlock(
      this.$textarea.value ?? this.$textarea.val(),
      caretPosition(this.$textarea)
    );
  }

  @bind
  toggleDirection() {
    let currentDir = this.$textarea.attr("dir")
        ? this.$textarea.attr("dir")
        : siteDir(),
      newDir = currentDir === "ltr" ? "rtl" : "ltr";

    this.$textarea.attr("dir", newDir).focus();
  }

  @bind
  applyList(sel, head, exampleKey, opts) {
    if (sel.value.includes("\n")) {
      this.applySurround(sel, head, "", exampleKey, opts);
    } else {
      const [hval, hlen] = getHead(head);
      if (sel.start === sel.end) {
        sel.value = i18n(`composer.${exampleKey}`);
      }

      const trimmedPre = sel.pre.trim();
      const number = sel.value.startsWith(hval)
        ? sel.value.slice(hlen)
        : `${hval}${sel.value}`;
      const preLines = trimmedPre.length ? `${trimmedPre}\n\n` : "";

      const trimmedPost = sel.post.trim();
      const post = trimmedPost.length ? `\n\n${trimmedPost}` : trimmedPost;

      this.value = `${preLines}${number}${post}`;
      this.selectText(preLines.length, number.length);
    }
  }

  @bind
  formatCode() {
    const sel = this.getSelected("", { lineVal: true });
    const selValue = sel.value;
    const hasNewLine = selValue.includes("\n");
    const isBlankLine = sel.lineVal.trim().length === 0;
    const isFourSpacesIndent =
      this.siteSettings.code_formatting_style === FOUR_SPACES_INDENT;

    if (!hasNewLine) {
      if (selValue.length === 0 && isBlankLine) {
        if (isFourSpacesIndent) {
          const example = i18n(`composer.code_text`);
          this.value = `${sel.pre}    ${example}${sel.post}`;
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
  }

  putCursorAtEnd() {
    putCursorAtEnd(this.textarea);
  }

  autocomplete() {
    return this.$textarea.autocomplete(...arguments);
  }
}
