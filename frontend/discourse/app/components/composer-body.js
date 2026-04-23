/* eslint-disable ember/no-classic-components, ember/no-observers, ember/require-tagless-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { classNameBindings } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import { waitForTransitionEnd } from "discourse/lib/animation-utils";
import discourseDebounce from "discourse/lib/debounce";
import discourseLater from "discourse/lib/later";
import Composer from "discourse/models/composer";

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
  @service capabilities;

  elementId = "reply-control";

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

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    cancel(this._lastKeyTimeout);
    this._lastKeyTimeout = discourseLater(() => {
      if (lastKeyUp !== this._lastKeyUp) {
        return;
      }
      this.appEvents.trigger("composer:find-similar");
    }, 1000);
  }

  @observes("composeState", "composer.{action,canEditTopicFeaturedLink}")
  _triggerComposerResized() {
    schedule("afterRender", () => {
      discourseDebounce(this, this.composerResized, 300);
    });
  }

  @observes("composeState")
  async _onComposerOpen() {
    // Skip if not opening, unmounted, or already awaiting the open transition —
    // the in-flight wait will fire (or not) based on state at resolution time.
    if (
      !this.element ||
      this.composeState !== Composer.OPEN ||
      this._awaitingComposerOpen
    ) {
      return;
    }

    this._awaitingComposerOpen = true;
    try {
      await waitForTransitionEnd(this.element, "height");

      if (
        this.isDestroying ||
        this.isDestroyed ||
        this.composeState !== Composer.OPEN
      ) {
        return;
      }

      this.appEvents.trigger("composer:opened");
    } finally {
      this._awaitingComposerOpen = false;
    }
  }

  composerResized() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
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
      if (event.propertyName === "max-width") {
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
}
