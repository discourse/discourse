import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import {
  buildEmojiUrl,
  emojiExists,
  emojiReplacementRegex,
  isCustomEmoji,
} from "pretty-text/emoji";
import { emojiOptions } from "discourse/lib/text";

const MAX_LENGTH = 16;
const MAX_EMOJI = 5;

const UNICODE_EMOJI_REGEX = new RegExp(emojiReplacementRegex, "g");
const EMOJI_SHORTCODE_REGEX = /(^|\W):([^:]+):/;

function getStats(element) {
  let length = 0;
  let emojiCount = 0;

  for (const node of element.childNodes) {
    if (node.nodeType === Node.TEXT_NODE) {
      const text = node.textContent;
      const unicodeMatches = text.match(UNICODE_EMOJI_REGEX);
      if (unicodeMatches) {
        emojiCount += unicodeMatches.length;
        length += text.replace(UNICODE_EMOJI_REGEX, "x").length;
      } else {
        length += text.length;
      }
    } else if (node.nodeName === "IMG" && node.classList.contains("emoji")) {
      length += 1;
      emojiCount += 1;
    }
  }

  return { length, emojiCount };
}

function serialize(element) {
  let result = "";

  for (const node of element.childNodes) {
    if (node.nodeType === Node.TEXT_NODE) {
      result += node.textContent;
    } else if (node.nodeName === "IMG" && node.classList.contains("emoji")) {
      result += node.alt;
    }
  }

  return result;
}

function createEmojiImg(code) {
  const opts = emojiOptions();
  const title = `:${code}:`;
  const src = buildEmojiUrl(code, opts);
  const img = document.createElement("img");
  img.className = isCustomEmoji(code, opts) ? "emoji emoji-custom" : "emoji";
  img.alt = title;
  img.title = title;
  img.src = src;
  return img;
}

function placeCursorAtEnd(element) {
  const range = document.createRange();
  const sel = window.getSelection();
  range.selectNodeContents(element);
  range.collapse(false);
  sel.removeAllRanges();
  sel.addRange(range);
}

export default class BoostEditor extends Component {
  @tracked canAddEmoji = true;

  #editor = null;
  #previousHTML = "";

  @action
  setup(element) {
    this.#editor = element;
    next(() => element.focus());
  }

  @action
  handleInput() {
    this.#processEmojiShortcodes();

    const stats = getStats(this.#editor);
    if (stats.length > MAX_LENGTH || stats.emojiCount > MAX_EMOJI) {
      this.#editor.innerHTML = this.#previousHTML;
      placeCursorAtEnd(this.#editor);
      return;
    }

    this.#previousHTML = this.#editor.innerHTML;
    const value = serialize(this.#editor);
    this.#updateCanAddEmoji(stats);
    this.args.onChange?.(value);
  }

  @action
  handleKeyDown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.args.onSubmit?.();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.args.onClose?.();
    }
  }

  @action
  handlePaste(event) {
    event.preventDefault();
    const text = event.clipboardData.getData("text/plain");
    document.execCommand("insertText", false, text);
  }

  @action
  insertEmoji(code) {
    const stats = getStats(this.#editor);
    const needsSpace = this.#editor.childNodes.length > 0;
    const extraLength = needsSpace ? 2 : 1;

    if (
      stats.length + extraLength > MAX_LENGTH ||
      stats.emojiCount + 1 > MAX_EMOJI
    ) {
      return;
    }

    if (needsSpace) {
      this.#editor.appendChild(document.createTextNode(" "));
    }

    this.#editor.appendChild(createEmojiImg(code));
    placeCursorAtEnd(this.#editor);
    this.#previousHTML = this.#editor.innerHTML;
    const value = serialize(this.#editor);
    this.#updateCanAddEmoji(getStats(this.#editor));
    this.args.onChange?.(value);
  }

  @action
  focus() {
    this.#editor?.focus();
  }

  #updateCanAddEmoji(stats) {
    const spaceNeeded = this.#editor.childNodes.length > 0 ? 2 : 1;
    this.canAddEmoji =
      stats.length + spaceNeeded <= MAX_LENGTH && stats.emojiCount < MAX_EMOJI;
  }

  #processEmojiShortcodes() {
    const walker = document.createTreeWalker(
      this.#editor,
      NodeFilter.SHOW_TEXT
    );

    let node;
    while ((node = walker.nextNode())) {
      const match = node.textContent.match(EMOJI_SHORTCODE_REGEX);
      if (match && emojiExists(match[2])) {
        const code = match[2];
        const emojiStart = match.index + match[1].length;
        const emojiEnd = emojiStart + code.length + 2;
        const beforeText = node.textContent.slice(0, emojiStart);
        const afterText = node.textContent.slice(emojiEnd);
        const img = createEmojiImg(code);
        const parent = node.parentNode;

        if (afterText) {
          parent.insertBefore(
            document.createTextNode(afterText),
            node.nextSibling
          );
        }

        parent.insertBefore(img, node.nextSibling);

        if (beforeText) {
          node.textContent = beforeText;
        } else {
          parent.removeChild(node);
        }

        const range = document.createRange();
        const sel = window.getSelection();
        range.setStartAfter(img);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);

        break;
      }
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class="discourse-boosts__input"
      contenteditable="true"
      data-placeholder={{@placeholder}}
      {{didInsert this.setup}}
      {{on "input" this.handleInput}}
      {{on "keydown" this.handleKeyDown}}
      {{on "paste" this.handlePaste}}
    ></div>
    {{yield
      (hash
        insertEmoji=this.insertEmoji
        focus=this.focus
        canAddEmoji=this.canAddEmoji
      )
    }}
  </template>
}
