import { tracked } from "@glimmer/tracking";
import { cancel, later } from "@ember/runloop";

const DEFAULT_TYPING_DELAY = 15;

/**
 * SmoothStreamer provides a typing animation effect for streamed text updates.
 */
export default class SmoothStreamer {
  @tracked isStreaming = false;
  @tracked streamedText = "";
  typingTimer = null;
  streamedTextLength = 0;

  /**
   * @param {() => string} getRealtimeText - Function to retrieve the latest realtime text
   * @param {(value: string) => void} setRealtimeText - Function to update the realtime text
   * @param {number} [typingDelay] - Delay (in ms) between each character reveal
   */
  constructor(getRealtimeText, setRealtimeText, typingDelay) {
    this.getRealtimeText = getRealtimeText;
    this.setRealtimeText = setRealtimeText;
    this.typingDelay = typingDelay || DEFAULT_TYPING_DELAY;
  }

  /**
   * Retrieves the appropriate text: either the animated stream or the full realtime text.
   * @returns {string}
   */
  get renderedText() {
    return this.isStreaming ? this.streamedText : this.realtimeText;
  }

  /**
   * Retrieves the current realtime text.
   * @returns {string}
   */
  get realtimeText() {
    return this.getRealtimeText();
  }

  /**
   * Updates the realtime text.
   * @param {string} value - The new text value
   */
  set realtimeText(value) {
    this.setRealtimeText(value);
  }

  /**
   * Resets the streaming state, clearing all animation progress.
   */
  resetStreaming() {
    this.#cancelTypingTimer();
    this.isStreaming = false;
    this.streamedText = "";
    this.streamedTextLength = 0;
  }

  /**
   * Processes an update result (typically from MessageBus)
   * either completing the stream or continuing animation.
   * @param {object} result - The result object containing the new text and status
   * @param {string} newTextKey - The key in result that holds the new text value (e.g. if the JSON is { text: "Hello", done: false }, newTextKey would be "text")
   */
  async updateResult(result, newTextKey) {
    const newText = result[newTextKey];

    if (result?.done) {
      this.streamedText = newText;
      this.realtimeText = newText;
      this.isStreaming = false;

      // Clear pending animations
      this.#cancelTypingTimer();
    } else if (newText.length > this.realtimeText.length) {
      this.realtimeText = newText;
      this.isStreaming = true;
      await this.#onTextUpdate();
    }
  }

  /**
   * Types out the next character in the streaming text.
   * Private method.
   */
  #typeCharacter() {
    if (this.streamedTextLength < this.realtimeText.length) {
      this.streamedText += this.realtimeText.charAt(this.streamedTextLength);
      this.streamedTextLength++;

      this.typingTimer = later(this, this.#typeCharacter, this.typingDelay);
    } else {
      this.typingTimer = null;
    }
  }

  /**
   * Handles text updates and restarts the typing animation.
   * Private method.
   */
  #onTextUpdate() {
    this.#cancelTypingTimer();
    this.#typeCharacter();
  }

  /**
   * Cancels any pending typing animation.
   * Private method.
   */
  #cancelTypingTimer() {
    if (this.typingTimer) {
      cancel(this.typingTimer);
    }
  }
}
