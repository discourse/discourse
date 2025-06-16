import Component from "@ember/component";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import { isiPad } from "discourse/lib/utilities";
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

  @discourseComputed("composer.action")
  prefixedComposerAction(action) {
    return action ? `composer-action-${action}` : "";
  }

  @discourseComputed("currentUser.primary_group_name")
  currentUserPrimaryGroupClass(primaryGroupName) {
    return primaryGroupName && `group-${primaryGroupName}`;
  }

  @discourseComputed("composer.composeState")
  composeState(composeState) {
    return composeState || Composer.CLOSED;
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

  composerResized() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    this.appEvents.trigger("composer:resized");
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    const triggerOpen = () => {
      if (this.get("composer.composeState") === Composer.OPEN) {
        this.appEvents.trigger("composer:opened");
      }
    };
    triggerOpen();

    this.element.addEventListener("transitionend", (event) => {
      if (event.propertyName === "height") {
        triggerOpen();
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
      (e.ctrlKey || e.metaKey || (isiPad() && e.altKey))
    ) {
      // Ctrl+Enter or Cmd+Enter
      // iPad physical keyboard does not offer Command or Ctrl detection
      // so use Alt+Enter
      e.preventDefault();
      this.save(undefined, e);
    }
  }
}
