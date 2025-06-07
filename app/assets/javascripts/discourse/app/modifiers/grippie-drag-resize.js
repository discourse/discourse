import { registerDestructor } from "@ember/destroyable";
import { throttle } from "@ember/runloop";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { headerOffset } from "discourse/lib/offset-calculator";

const START_DRAG_EVENTS = ["touchstart", "mousedown"];
const DRAG_EVENTS = ["touchmove", "mousemove"];
const END_DRAG_EVENTS = ["touchend", "mouseup"];
const THROTTLE_RATE = 20;

function mouseYPos(event) {
  return (
    event.clientY ||
    (event.touches && event.touches[0] && event.touches[0].clientY)
  );
}

export default class GrippieDragResize extends Modifier {
  @service capabilities;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  startDragHandler(
    resizableElement,
    grippiePosition,
    onDragStart,
    onThrottledDrag,
    onDragEnd,
    event
  ) {
    event.preventDefault();

    this.origResizableElement = resizableElement.offsetHeight;
    this.lastMousePos = mouseYPos(event);
    this._throttledPeformDragHandler = this.throttledPerformDrag.bind(
      this,
      resizableElement,
      grippiePosition,
      onThrottledDrag
    );
    this._endDragHandler = this.endDragHandler.bind(
      this,
      resizableElement,
      onDragEnd
    );

    DRAG_EVENTS.forEach((dragEvent) => {
      document.addEventListener(dragEvent, this._throttledPeformDragHandler, {
        capture: true,
      });
    });

    END_DRAG_EVENTS.forEach((endDragEvent) => {
      document.addEventListener(endDragEvent, this._endDragHandler);
    });

    onDragStart?.();
  }

  endDragHandler(resizableElement, onDragEnd) {
    onDragEnd?.();

    DRAG_EVENTS.forEach((dragEvent) => {
      document.removeEventListener(
        dragEvent,
        this._throttledPeformDragHandler,
        {
          capture: true,
        }
      );
    });

    END_DRAG_EVENTS.forEach((endDragEvent) => {
      document.removeEventListener(endDragEvent, this._endDragHandler);
    });

    resizableElement.classList.remove("clear-transitions");
    resizableElement.focus();
  }

  throttledPerformDrag(
    resizableElement,
    grippiePosition,
    onThrottledDrag,
    event
  ) {
    event.preventDefault();
    throttle(
      this,
      () =>
        this.performDragHandler(
          resizableElement,
          grippiePosition,
          onThrottledDrag
        ),
      event,
      THROTTLE_RATE
    );
  }

  performDragHandler(resizableElement, grippiePosition, onThrottledDrag) {
    resizableElement.classList.add("clear-transitions");
    const currentMousePos = mouseYPos(event);

    let size;
    if (grippiePosition === "top") {
      size = this.origResizableElement + (this.lastMousePos - currentMousePos);
    } else {
      size = this.origResizableElement - (this.lastMousePos - currentMousePos);
    }
    const maxHeight = this.capabilities.isTablet
      ? window.innerHeight
      : window.innerHeight - headerOffset();
    size = Math.min(size, maxHeight);
    const elementMinHeight = getComputedStyle(resizableElement).minHeight;
    const minHeight = parseInt(
      elementMinHeight === "auto" ? 250 : elementMinHeight,
      10
    );
    size = Math.max(minHeight, size);

    onThrottledDrag?.(size);
  }

  modify(
    element,
    [
      resizableElementSelector,
      grippiePosition,
      onDragStart,
      onThrottledDrag,
      onDragEnd,
    ]
  ) {
    this.element = element;
    this.resizableElement = document.querySelector(resizableElementSelector);

    this._startDragHandler = this.startDragHandler.bind(
      this,
      this.resizableElement,
      grippiePosition,
      onDragStart,
      onThrottledDrag,
      onDragEnd
    );

    START_DRAG_EVENTS.forEach((startDragEvent) => {
      element.addEventListener(startDragEvent, this._startDragHandler, {
        passive: false,
      });
    });
  }

  cleanup() {
    if (this._startDragHandler) {
      START_DRAG_EVENTS.forEach((startDragEvent) => {
        this.element.removeEventListener(
          startDragEvent,
          this._startDragHandler
        );
      });
    }
  }
}
