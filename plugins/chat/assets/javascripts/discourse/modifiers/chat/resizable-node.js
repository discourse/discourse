import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

const MINIMUM_SIZE = 20;

export default class ResizableNode extends Modifier {
  @service capabilities;

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
      { vertical: true, horizontal: true, position: true, mutate: true },
      options
    );

    if (this.capabilities.touch) {
      this.element
        .querySelector(this.resizerSelector)
        ?.addEventListener("touchstart", this._startResize);
    } else {
      this.element
        .querySelector(this.resizerSelector)
        ?.addEventListener("mousedown", this._startResize);
    }
  }

  cleanup() {
    if (this.capabilities.touch) {
      this.element
        .querySelector(this.resizerSelector)
        ?.addEventListener("touchstart", this._startResize);
    } else {
      this.element
        .querySelector(this.resizerSelector)
        ?.removeEventListener("mousedown", this._startResize);
    }
  }

  @bind
  _startResize(event) {
    event.preventDefault();

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

    if (this.capabilities.touch) {
      window.addEventListener("touchmove", this._resize);
      window.addEventListener("touchend", this._stopResize);
    } else {
      window.addEventListener("mousemove", this._resize);
      window.addEventListener("mouseup", this._stopResize);
    }
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

    if (this.options.horizontal && width > MINIMUM_SIZE) {
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

    if (this.options.vertical && height > MINIMUM_SIZE) {
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

    this.didResizeContainer?.(this.element, { width, height });
  }

  @bind
  _stopResize() {
    if (this.capabilities.touch) {
      window.removeEventListener("touchmove", this._resize);
      window.removeEventListener("touchend", this._stopResize);
    } else {
      window.removeEventListener("mousemove", this._resize);
      window.removeEventListener("mouseup", this._stopResize);
    }
  }

  _eventValueForProperty(event, property) {
    if (this.capabilities.touch) {
      return event.changedTouches[0][property];
    } else {
      return event[property];
    }
  }
}
