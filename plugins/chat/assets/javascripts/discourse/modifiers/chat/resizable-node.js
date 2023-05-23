import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";
import { bind } from "discourse-common/utils/decorators";
import { throttle } from "@ember/runloop";

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
  _originalMouseX = 0;
  _originalMouseY = 0;

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

    this.element
      .querySelector(this.resizerSelector)
      ?.addEventListener("mousedown", this._startResize);
  }

  cleanup() {
    this.element
      .querySelector(this.resizerSelector)
      ?.removeEventListener("mousedown", this._startResize);
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
    this._originalMouseX = event.pageX;
    this._originalMouseY = event.pageY;

    window.addEventListener("mousemove", this._resize);
    window.addEventListener("mouseup", this._stopResize);
  }

  @bind
  _resize(event) {
    throttle(this, this._resizeThrottled, event, 24);
  }

  /*
    The bulk of the logic is to calculate the new width and height of the element
    based on the current mouse position: width is calculated by subtracting
    the difference between the current event.pageX and the original this._originalMouseX
    from the original this._originalWidth, and rounding up to the nearest integer.
    height is calculated in a similar way using event.pageY and this._originalMouseY.

    In this example (B) is the current element top/left and (A) is x/y of the mouse after dragging:

    A------
    |     |
    |  B--|
    |  |  |
    -------
  */
  @bind
  _resizeThrottled(event) {
    let width = this._originalWidth;
    let diffWidth = event.pageX - this._originalMouseX;
    if (document.documentElement.classList.contains("rtl")) {
      width = Math.ceil(width + diffWidth);
    } else {
      width = Math.ceil(width - diffWidth);
    }

    const height = Math.ceil(
      this._originalHeight - (event.pageY - this._originalMouseY)
    );

    const newStyle = {};

    if (this.options.horizontal && width > MINIMUM_SIZE) {
      newStyle.width = width + "px";

      if (this.options.position) {
        newStyle.left =
          Math.ceil(this._originalX + (event.pageX - this._originalMouseX)) +
          "px";
      }
    }

    if (this.options.vertical && height > MINIMUM_SIZE) {
      newStyle.height = height + "px";

      if (this.options.position) {
        newStyle.top =
          Math.ceil(this._originalY + (event.pageY - this._originalMouseY)) +
          "px";
      }
    }

    if (this.options.mutate) {
      Object.assign(this.element.style, newStyle);
    }

    this.didResizeContainer?.(this.element, { width, height });
  }

  @bind
  _stopResize() {
    window.removeEventListener("mousemove", this._resize);
    window.removeEventListener("mouseup", this._stopResize);
  }
}
