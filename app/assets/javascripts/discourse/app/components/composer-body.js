import Component from "@ember/component";
import { cancel, schedule, throttle } from "@ember/runloop";
import { classNameBindings } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed, { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import { headerOffset } from "discourse/lib/offset-calculator";
import { isiPad } from "discourse/lib/utilities";
import Composer from "discourse/models/composer";

const START_DRAG_EVENTS = ["touchstart", "mousedown"];
const DRAG_EVENTS = ["touchmove", "mousemove"];
const END_DRAG_EVENTS = ["touchend", "mouseup"];

const THROTTLE_RATE = 20;

function mouseYPos(e) {
  return e.clientY || (e.touches && e.touches[0] && e.touches[0].clientY);
}

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

  setupComposerResizeEvents() {
    this.origComposerSize = 0;
    this.lastMousePos = 0;

    START_DRAG_EVENTS.forEach((startDragEvent) => {
      this.element
        .querySelector(".grippie")
        ?.addEventListener(startDragEvent, this.startDragHandler, {
          passive: false,
        });
    });
  }

  @bind
  performDragHandler() {
    this.appEvents.trigger("composer:div-resizing");
    this.element.classList.add("clear-transitions");
    const currentMousePos = mouseYPos(event);

    let size = this.origComposerSize + (this.lastMousePos - currentMousePos);
    size = Math.min(size, window.innerHeight - headerOffset());
    const minHeight = parseInt(getComputedStyle(this.element).minHeight, 10);
    size = Math.max(minHeight, size);

    this.set("composer.composerHeight", `${size}px`);
    this.keyValueStore.set({
      key: "composerHeight",
      value: this.get("composer.composerHeight"),
    });
    document.documentElement.style.setProperty(
      "--composer-height",
      size ? `${size}px` : ""
    );

    this._triggerComposerResized();
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

  @bind
  startDragHandler(event) {
    event.preventDefault();

    this.origComposerSize = this.element.offsetHeight;
    this.lastMousePos = mouseYPos(event);

    DRAG_EVENTS.forEach((dragEvent) => {
      document.addEventListener(dragEvent, this.throttledPerformDrag);
    });

    END_DRAG_EVENTS.forEach((endDragEvent) => {
      document.addEventListener(endDragEvent, this.endDragHandler);
    });

    this.appEvents.trigger("composer:resize-started");
  }

  @bind
  endDragHandler() {
    this.appEvents.trigger("composer:resize-ended");

    DRAG_EVENTS.forEach((dragEvent) => {
      document.removeEventListener(dragEvent, this.throttledPerformDrag);
    });

    END_DRAG_EVENTS.forEach((endDragEvent) => {
      document.removeEventListener(endDragEvent, this.endDragHandler);
    });

    this.element.classList.remove("clear-transitions");
    this.element.focus();
  }

  @bind
  throttledPerformDrag(event) {
    event.preventDefault();
    throttle(this, this.performDragHandler, event, THROTTLE_RATE);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.setupComposerResizeEvents();

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

    START_DRAG_EVENTS.forEach((startDragEvent) => {
      this.element
        .querySelector(".grippie")
        ?.removeEventListener(startDragEvent, this.startDragHandler);
    });

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
