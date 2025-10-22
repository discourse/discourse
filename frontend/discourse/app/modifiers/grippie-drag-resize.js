import { registerDestructor } from "@ember/destroyable";
import { cancel, throttle } from "@ember/runloop";
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

/**
 * This modifier allows a target element to be resized vertically
 * by dragging an element, referred to as a "grippie", positioned
 * at the top or bottom of the target element.
 *
 * For example, a code editor or a composer like this:
 *
 * -------------------------------------
 * |                                   |
 * |                                   | <- resizableElement
 * |                                   |
 * |                                   |
 * ------------------------------------
 * |             =======               | <- grippie
 * ------------------------------------
 */
export default class GrippieDragResize extends Modifier {
  @service capabilities;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  startDragHandler(event) {
    event.preventDefault();

    // Only allow left-click dragging
    // c.f. https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent/button#value
    if (event.type === "mousedown" && event.button !== 0) {
      return;
    }

    this.originalResizableElementHeight = this.resizableElement.offsetHeight;
    this.lastMousePos = mouseYPos(event);
    this._throttledPeformDragHandler = this.throttledPerformDrag.bind(this);
    this._endDragHandler = this.endDragHandler.bind(this);

    DRAG_EVENTS.forEach((dragEvent) => {
      document.addEventListener(dragEvent, this._throttledPeformDragHandler, {
        capture: true,
      });
    });

    END_DRAG_EVENTS.forEach((endDragEvent) => {
      document.addEventListener(endDragEvent, this._endDragHandler);
    });

    this.onDragStart?.();
  }

  endDragHandler() {
    this.onDragEnd?.();

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

    this.resizableElement.classList.remove("clear-transitions");
    this.resizableElement.focus();
  }

  throttledPerformDrag(event) {
    event.preventDefault();
    this.throttledDragHandler = throttle(
      this,
      () =>
        this.performDragHandler(
          this.resizableElement,
          this.grippiePosition,
          this.onThrottledDrag
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
      size =
        this.originalResizableElementHeight +
        (this.lastMousePos - currentMousePos);
    } else {
      size =
        this.originalResizableElementHeight -
        (this.lastMousePos - currentMousePos);
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

  /*
   * @param {HTMLElement} element - The element to which the modifier is applied, the grippie.
   * @param {string} resizableElementSelector - A CSS selector to find the resizable element,
   *   should be something like a code editor or composer textarea.
   * @param {string} grippiePosition - The position of the grippie relative to
   *   resizableElementSelector, either "top" or "bottom".
   * @param {Object} [callbacks] - An object containing optional callback functions.
   * * onDragStart - Callback function to be called when dragging starts.
   * * onThrottledDrag - Callback function to be called during throttled
   *   drag events while moving the mouse.
   * * onDragEnd - Callback function to be called when dragging ends.
   */
  modify(element, [resizableElementSelector, grippiePosition, callbacks]) {
    this.element = element;
    this.resizableElement = document.querySelector(resizableElementSelector);
    this.grippiePosition = grippiePosition;
    this.onDragStart = callbacks.onDragStart;
    this.onThrottledDrag = callbacks.onThrottledDrag;
    this.onDragEnd = callbacks.onDragEnd;

    this._startDragHandler = this.startDragHandler.bind(this);

    START_DRAG_EVENTS.forEach((startDragEvent) => {
      element.addEventListener(startDragEvent, this._startDragHandler, {
        passive: false,
      });
    });
  }

  cleanup() {
    cancel(this.throttledDragHandler);

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
