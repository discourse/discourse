import { tracked } from "@glimmer/tracking";
import { cancel, later } from "@ember/runloop";
import loadJSDiff from "discourse/lib/load-js-diff";
import { escapeExpression } from "discourse/lib/utilities";

const DEFAULT_CHAR_TYPING_DELAY = 10;
const STREAMING_DIFF_TRUNCATE_THRESHOLD = 0.1;
const STREAMING_DIFF_TRUNCATE_BUFFER = 10;
const RUSH_MAX_TICKS = 10; // ≤ 10 visual diff refreshes
const RUSH_TICK_INTERVAL = 100; // 100 ms between them → ≤ 1 s total

export default class DiffStreamer {
  @tracked isStreaming = false;
  @tracked words = [];
  @tracked lastResultText = "";
  @tracked diff = this.selectedText;
  @tracked suggestion = "";
  @tracked isDone = false;
  @tracked isThinking = true;

  typingTimer = null;
  currentWordIndex = 0;
  currentCharIndex = 0;
  jsDiff = null;

  bufferedToken = null;

  rushMode = false;
  rushBatchSize = 1;
  rushTicksLeft = 0;

  receivedFinalUpdate = false;

  /**
   * Initializes the DiffStreamer with initial text and typing delay.
   * @param {string} selectedText - The original text to diff against.
   * @param {number} typingDelay - (Optional) character typing delay in ms.
   */
  constructor(selectedText, typingDelay) {
    this.selectedText = selectedText;
    this.typingDelay = typingDelay || DEFAULT_CHAR_TYPING_DELAY;
    this.loadJSDiff();
  }

  /**
   * Loads the jsDiff library asynchronously.
   */
  async loadJSDiff() {
    this.jsDiff = await loadJSDiff();
  }

  /**
   * Main entry point for streaming updates from the backend.
   * Handles both incremental and final updates.
   * @param {object} result - The result object containing the new text and status
   * @param {string} newTextKey - The key in result that holds the new text value (e.g. if the JSON is { text: "Hello", done: false }, newTextKey would be "text")
   */
  async updateResult(result, newTextKey) {
    if (this.receivedFinalUpdate) {
      return;
    }

    if (!this.jsDiff) {
      await this.loadJSDiff();
    }

    this.isThinking = false;
    const newText = result[newTextKey];
    const gotDoneFlag = !!result?.done;

    if (gotDoneFlag) {
      this.receivedFinalUpdate = true;
      if (this.typingTimer) {
        cancel(this.typingTimer);
        this.typingTimer = null;
      }

      // flush buffered token so everything is renderable
      if (this.bufferedToken) {
        this.words.push(this.bufferedToken);
        this.bufferedToken = null;
      }

      // tokenise whatever tail we haven’t processed yet
      const tail = newText.slice(this.lastResultText.length);
      if (tail.length) {
        this.words.push(...this.#tokenize(tail));
      }

      const charsLeft = newText.length - this.suggestion.length;
      if (charsLeft <= 0) {
        this.suggestion = newText;
        this.diff = this.#formatDiffWithTags(
          this.jsDiff.diffWordsWithSpace(this.selectedText, newText),
          false
        );
        this.isStreaming = false;
        this.isDone = true;
        return;
      }

      this.rushBatchSize = Math.ceil(charsLeft / RUSH_MAX_TICKS);
      this.rushTicksLeft = RUSH_MAX_TICKS;
      this.rushMode = true;
      this.isStreaming = true;
      this.lastResultText = newText;

      this.#streamNextChar();
      return;
    }

    const delta = newText.slice(this.lastResultText.length);
    if (!delta) {
      this.lastResultText = newText;
      return;
    }

    // combine any previous buffered token with new delta and retokenize
    const combined = (this.bufferedToken || "") + delta;
    const tokens = this.#tokenize(combined);
    this.bufferedToken = tokens.pop() || null;

    if (tokens.length) {
      this.words.push(...tokens);
    }

    this.isStreaming = true;
    if (!this.typingTimer) {
      this.#streamNextChar();
    }

    this.lastResultText = newText;
  }

  /**
   * Resets the streamer's internal state to allow reuse.
   */
  reset() {
    this.diff = "";
    this.suggestion = "";
    this.lastResultText = "";
    this.words = [];
    this.currentWordIndex = 0;
    this.currentCharIndex = 0;
    this.bufferedToken = null;

    this.isStreaming = false;
    this.isDone = false;
    this.receivedFinalUpdate = false;
    this.isThinking = true;

    this.rushMode = false;
    this.rushBatchSize = 1;
    this.rushTicksLeft = 0;

    if (this.typingTimer) {
      cancel(this.typingTimer);
      this.typingTimer = null;
    }
  }

  /**
   * Computes a truncated diff during streaming to avoid excessive churn.
   * @param {string} original - The original text.
   * @param {string} suggestion - The partially streamed suggestion.
   * @returns {Array} Array of diff parts with `.added`, `.removed`, and `.value`.
   */
  streamingDiff(original, suggestion) {
    const max = Math.floor(
      suggestion.length +
        suggestion.length * STREAMING_DIFF_TRUNCATE_THRESHOLD +
        STREAMING_DIFF_TRUNCATE_BUFFER
    );
    const head = original.slice(0, max);
    const tail = original.slice(max);

    const output = this.jsDiff.diffWordsWithSpace(head, suggestion);

    if (tail.length) {
      let last = output.at(-1);
      let secondLast = output.at(-2);

      if (last.added && secondLast?.removed) {
        output.splice(-2, 2, last, secondLast);
        last = secondLast;
      }

      if (!last.removed) {
        last = { added: false, removed: true, value: "" };
        output.push(last);
      }
      last.value += tail;
    }
    return output;
  }

  /**
   * Internal loop that emits the next character(s) to simulate typing.
   * Works in both normal and rush mode.
   */
  #streamNextChar() {
    if (!this.isStreaming) {
      return;
    }

    const limit = this.rushMode ? this.rushBatchSize : 1;
    let emitted = 0;
    while (emitted < limit && this.currentWordIndex < this.words.length) {
      const token = this.words[this.currentWordIndex];
      this.suggestion += token.charAt(this.currentCharIndex);
      this.currentCharIndex++;
      emitted++;

      if (this.currentCharIndex >= token.length) {
        this.currentWordIndex++;
        this.currentCharIndex = 0;
      }
    }

    let refresh = false;
    if (this.rushMode) {
      if (this.rushTicksLeft > 0) {
        this.rushTicksLeft--;
        refresh = true;
      }
    } else {
      refresh = this.currentCharIndex === 0;
    }

    if (refresh || this.currentWordIndex >= this.words.length) {
      const useStreaming =
        this.currentWordIndex < this.words.length || this.rushMode;
      this.diff = this.#formatDiffWithTags(
        useStreaming
          ? this.streamingDiff(this.selectedText, this.suggestion)
          : this.jsDiff.diffWordsWithSpace(this.selectedText, this.suggestion),
        !this.rushMode
      );
    }

    const doneStreaming = this.currentWordIndex >= this.words.length;

    if (doneStreaming) {
      this.isStreaming = false;
      this.rushMode = false;
      this.typingTimer = null;

      if (this.receivedFinalUpdate) {
        this.isDone = true;
      }
    } else {
      const delay = this.rushMode ? RUSH_TICK_INTERVAL : this.typingDelay;
      this.typingTimer = later(this, this.#streamNextChar, delay);
    }
  }

  /**
   * Splits a string into tokens, preserving whitespace as separate entries.
   * @param {string} text - The input string.
   * @returns {Array} Array of tokens.
   */
  #tokenize(text) {
    return text.split(/(?<=\S)(?=\s)/);
  }

  /**
   * Wraps a chunk of text in appropriate HTML tags based on its diff type.
   * @param {string} text - The text chunk.
   * @param {string} type - The type: 'added', 'removed', or 'unchanged'.
   * @returns {string} HTML string.
   */
  #wrapChunk(text, type) {
    if (type === "added") {
      return `<ins>${text}</ins>`;
    }
    if (type === "removed") {
      return /^\s+$/.test(text) ? "" : `<del>${text}</del>`;
    }
    return `<span>${text}</span>`;
  }

  /**
   * Converts a diff array into a string of HTML with highlight markup.
   * @param {Array} diffArray - The array from a diff function.
   * @param {boolean} highlightLastWord - Whether to highlight the last non-removed word.
   * @returns {string} HTML representation of the diff.
   */
  #formatDiffWithTags(diffArray, highlightLastWord = true) {
    const words = [];
    diffArray.forEach((part) =>
      (part.value.match(/\S+|\s+/g) || []).forEach((tok) =>
        words.push({
          text: tok,
          type: part.added ? "added" : part.removed ? "removed" : "unchanged",
        })
      )
    );

    let lastIndex = -1;
    if (highlightLastWord) {
      for (let i = words.length - 1; i >= 0; i--) {
        if (words[i].type !== "removed" && /\S/.test(words[i].text)) {
          lastIndex = i;
          break;
        }
      }
    }

    const output = [];
    for (let i = 0; i <= lastIndex; i++) {
      let { text, type } = words[i];
      text = escapeExpression(text);
      if (/^\s+$/.test(text)) {
        output.push(text);
        continue;
      }
      let chunk = this.#wrapChunk(text, type);
      if (highlightLastWord && i === lastIndex) {
        chunk = `<mark class="highlight">${chunk}</mark>`;
      }
      output.push(chunk);
    }

    for (let i = lastIndex + 1; i < words.length; ) {
      const type = words[i].type;
      let buf = "";
      while (i < words.length && words[i].type === type) {
        buf += words[i++].text;
      }
      output.push(this.#wrapChunk(escapeExpression(buf), type));
    }

    return output.join("");
  }
}
