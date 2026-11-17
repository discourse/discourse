/* eslint-disable ember/no-classic-components, ember/no-observers, ember/require-tagless-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { classNameBindings } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import discourseDebounce from "discourse/lib/debounce";
import discourseLater from "discourse/lib/later";
import Composer from "discourse/models/composer";

// A space or new line typed after the end of a sentence counts as a pause.
const SENTENCE_END_REGEXP = /(?:[.!?]\s|\n)$/;

@classNameBindings(
  "composer.creatingPrivateMessage:private-message",
  "composeState",
  "composer.loading",
  "prefixedComposerAction",
  "composer.canEditTitle:edit-title",
  "composer.createdPost:created-post",
  "composer.creatingTopic:topic",
  "composer.whisper:composing-whisper",
  "composer.sharedDraft:composing-shared-draft",
  "showPreview:show-preview:hide-preview",
  "currentUserPrimaryGroupClass"
)
export default class ComposerBody extends Component {
  @service appEvents;
  @service capabilities;

  elementId = "reply-control";

  #pausedComposer = null;
  #pausedContent = null;
  #typedComposer = null;
  #typedReply = "";

  @computed("composer.action")
  get prefixedComposerAction() {
    return this.composer?.action
      ? `composer-action-${dasherize(this.composer?.action)}`
      : "";
  }

  @computed("currentUser.primary_group_name")
  get currentUserPrimaryGroupClass() {
    return (
      this.currentUser?.primary_group_name &&
      `group-${this.currentUser?.primary_group_name}`
    );
  }

  @computed("composer.composeState")
  get composeState() {
    return this.composer?.composeState || Composer.CLOSED;
  }

  keyUp() {
    this.typed();

    const lastKeyUp = new Date();
    this._lastKeyUp = lastKeyUp;

    const composer = this.composer;
    if (this.#appendedSentenceEnd(composer)) {
      this.#typingPaused(composer);
    }

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    cancel(this._lastKeyTimeout);
    this._lastKeyTimeout = discourseLater(() => {
      if (lastKeyUp !== this._lastKeyUp) {
        return;
      }
      this.appEvents.trigger("composer:find-similar");

      if (this.composer === composer) {
        this.#typingPaused(composer);
      }
    }, 1000);
  }

  composerResized() {
    if (!this.element || this.isDestroying) {
      return;
    }

    this.appEvents.trigger("composer:resized");
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    if (this.composeState === Composer.OPEN) {
      this.appEvents.trigger("composer:opened");
    }

    this.element.addEventListener("transitionend", (event) => {
      if (
        event.propertyName === "height" ||
        event.propertyName === "max-width"
      ) {
        this.composerResized();
      }
    });
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    cancel(this._lastKeyTimeout);
  }

  click() {
    this.openIfDraft();
  }

  keyDown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      this.cancelled();
    } else if (
      e.key === "Enter" &&
      (e.ctrlKey || e.metaKey || (this.capabilities.isIpadOS && e.altKey))
    ) {
      // Ctrl+Enter or Cmd+Enter
      // iPad physical keyboard does not offer Command or Ctrl detection
      // so use Alt+Enter
      e.preventDefault();
      this.save(undefined, e);
    }
  }

  // Only an edit at the end counts, so editing earlier text in a reply that
  // already ends a sentence doesn't fire on every key.
  #appendedSentenceEnd(composer) {
    const reply = composer?.reply || "";
    const previous = composer === this.#typedComposer ? this.#typedReply : "";

    this.#typedComposer = composer;
    this.#typedReply = reply;

    return (
      reply.length > previous.length &&
      reply.startsWith(previous) &&
      SENTENCE_END_REGEXP.test(reply)
    );
  }

  #typingPaused(composer) {
    const content = `${composer?.title}\n${composer?.reply}`;

    // Only pauses after an edit count, so a sentence end and the idle timer
    // that follows it fire once.
    if (composer === this.#pausedComposer && content === this.#pausedContent) {
      return;
    }

    this.#pausedComposer = composer;
    this.#pausedContent = content;
    this.appEvents.trigger("composer:typing-paused", composer);
  }

  @observes("composeState", "composer.{action,canEditTopicFeaturedLink}")
  _triggerComposerResized() {
    schedule("afterRender", () => {
      discourseDebounce(this, this.composerResized, 300);
    });
  }

  @observes("composeState")
  _onComposerOpen() {
    if (this.composeState === Composer.OPEN) {
      this.appEvents.trigger("composer:opened");
    }
  }
}
