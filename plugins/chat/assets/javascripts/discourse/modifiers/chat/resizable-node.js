import { registerDestructor } from "@ember/destroyable";
import { cancel, throttle } from "@ember/runloop";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

const MINIMUM_SIZE = 20;

export default class ResizableNode extends Modifier {
  element = null;
  resizerSelector = null;
  didResizeContainer = null;
  options = null;

  _originalWidth = 0;
  _originalHeight = 0;
  _originalX = 0;
  _originalY = 0;
  _originalPageX = 0;
  _originalPageY = 0;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [resizerSelector, didResizeContainer, options = {}]) {
    this.resizerSelector = resizerSelector;
    this.element = element;
    this.didResizeContainer = didResizeContainer;
    this.options = Object.assign(
      {
        vertical: true,
        horizontal: true,
        position: true,
        mutate: true,
        resetOnWindowResize: false,
      },
      options
    );

    this.element
      .querySelector(this.resizerSelector)
      ?.addEventListener("touchstart", this._startResize);
    this.element
      .querySelector(this.resizerSelector)
      ?.addEventListener("mousedown", this._startResize);

    window.addEventListener("resize", this._resizeWindow);
  }

  cleanup() {
    this.element
      .querySelector(this.resizerSelector)
      ?.removeEventListener("touchstart", this._startResize);
    this.element
      .querySelector(this.resizerSelector)
      ?.removeEventListener("mousedown", this._startResize);

    window.removeEventListener("resize", this._resizeWindow);
    cancel(this._throttledResizeHandler);
  }

  @bind
  _startResize(event) {
    event.preventDefault();

    this._minimumWidth = parseFloat(
      getComputedStyle(this.element, null)
        .getPropertyValue("min-width")
        .replace("px", "") || MINIMUM_SIZE
    );

    this._minimumHeight = parseFloat(
      getComputedStyle(this.element, null)
        .getPropertyValue("min-height")
        .replace("px", "") || MINIMUM_SIZE
    );

    this._originalWidth = parseFloat(
      getComputedStyle(this.element, null)
        .getPropertyValue("width")
        .replace("px", "")
    );
    this._originalHeight = parseFloat(
      getComputedStyle(this.element, null)
        .getPropertyValue("height")
        .replace("px", "")
    );
    this._originalX = this.element.getBoundingClientRect().left;
    this._originalY = this.element.getBoundingClientRect().top;

    this._originalPageX = this._eventValueForProperty(event, "pageX");
    this._originalPageY = this._eventValueForProperty(event, "pageY");

    window.addEventListener("touchmove", this._resize);
    window.addEventListener("touchend", this._stopResize);
    window.addEventListener("mousemove", this._resize);
    window.addEventListener("mouseup", this._stopResize);
  }

  /*
    The bulk of the logic is to calculate the new width and height of the element
    based on the current position on page: width is calculated by subtracting
    the difference between the current pageX and the original this._originalPageX
    from the original this._originalWidth, and rounding up to the nearest integer.
    height is calculated in a similar way using pageY and this._originalPageY.

    In this example (B) is the current element top/left and (A) is x/y of the mouse after dragging:

    A------
    |     |
    |  B--|
    |  |  |
    -------
  */
  @bind
  _resize(event) {
    let width = this._originalWidth;
    let diffWidth =
      this._eventValueForProperty(event, "pageX") - this._originalPageX;
    if (document.documentElement.classList.contains("rtl")) {
      width = Math.ceil(width + diffWidth);
    } else {
      width = Math.ceil(width - diffWidth);
    }

    const height = Math.ceil(
      this._originalHeight -
        (this._eventValueForProperty(event, "pageY") - this._originalPageY)
    );

    const newStyle = {};
    if (this.options.horizontal && width >= this._minimumWidth) {
      newStyle.width = width + "px";

      if (this.options.position) {
        newStyle.left =
          Math.ceil(
            this._originalX +
              (this._eventValueForProperty(event, "pageX") -
                this._originalPageX)
          ) + "px";
      }
    }

    if (this.options.vertical && height >= this._minimumHeight) {
      newStyle.height = height + "px";

      if (this.options.position) {
        newStyle.top =
          Math.ceil(
            this._originalY +
              (this._eventValueForProperty(event, "pageY") -
                this._originalPageY)
          ) + "px";
      }
    }

    if (this.options.mutate) {
      Object.assign(this.element.style, newStyle);
    }

    this.didResizeContainer?.(this.element, {
      width: width >= this._minimumWidth ? width : this._minimumWidth,
      height: height >= this._minimumHeight ? height : this._minimumHeight,
    });
  }

  @bind
  _resizeWindow() {
    if (!this.options.resetOnWindowResize) {
      return;
    }

    this._throttledResizeHandler = throttle(this, this._throttledResize, 100);
  }

  @bind
  _throttledResize() {
    const style = {};
    if (this.options.vertical) {
      style.height = "auto";
    }
    if (this.options.horizontal) {
      style.width = "auto";
    }
    Object.assign(this.element.style, style);
  }

  @bind
  _stopResize() {
    window.removeEventListener("touchmove", this._resize);
    window.removeEventListener("touchend", this._stopResize);
    window.removeEventListener("mousemove", this._resize);
    window.removeEventListener("mouseup", this._stopResize);
  }

  _eventValueForProperty(event, property) {
    if (event.changedTouches) {
      return event.changedTouches[0][property];
    } else {
      return event[property];
    }
  }
}
