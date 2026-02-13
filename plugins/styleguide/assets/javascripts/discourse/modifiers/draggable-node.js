import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";

export default class DraggableNode extends Modifier {
  element = null;
  handleSelector = null;
  onMove = null;
  isDragging = false;
  startX = 0;
  startY = 0;
  startLeft = 0;
  startTop = 0;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, () => this.cleanup());
  }

  modify(element, [handleSelector], { onMove }) {
    this.element = element;
    this.handleSelector = handleSelector;
    this.onMove = onMove;

    this.cleanup();

    this._onMouseDown = this._handleMouseDown.bind(this);
    this._onMouseMove = this._handleMouseMove.bind(this);
    this._onMouseUp = this._handleMouseUp.bind(this);
    this._onTouchStart = this._handleTouchStart.bind(this);
    this._onTouchMove = this._handleTouchMove.bind(this);
    this._onTouchEnd = this._handleMouseUp.bind(this);

    const handle = element.querySelector(handleSelector);
    if (handle) {
      handle.addEventListener("mousedown", this._onMouseDown);
      handle.addEventListener("touchstart", this._onTouchStart, {
        passive: false,
      });
    }
  }

  _handleMouseDown(e) {
    e.preventDefault();
    this._startDrag(e.clientX, e.clientY);
    window.addEventListener("mousemove", this._onMouseMove);
    window.addEventListener("mouseup", this._onMouseUp);
  }

  _handleTouchStart(e) {
    e.preventDefault();
    const touch = e.touches[0];
    this._startDrag(touch.clientX, touch.clientY);
    window.addEventListener("touchmove", this._onTouchMove, {
      passive: false,
    });
    window.addEventListener("touchend", this._onTouchEnd);
  }

  _startDrag(clientX, clientY) {
    this.isDragging = true;
    this.startX = clientX;
    this.startY = clientY;
    const rect = this.element.getBoundingClientRect();
    this.startLeft = rect.left;
    this.startTop = rect.top;
  }

  _handleMouseMove(e) {
    if (!this.isDragging) {
      return;
    }
    this._moveTo(e.clientX, e.clientY);
  }

  _handleTouchMove(e) {
    if (!this.isDragging) {
      return;
    }
    e.preventDefault();
    const touch = e.touches[0];
    this._moveTo(touch.clientX, touch.clientY);
  }

  _moveTo(clientX, clientY) {
    const deltaX = clientX - this.startX;
    const deltaY = clientY - this.startY;
    const newLeft = this.startLeft + deltaX;
    const newTop = this.startTop + deltaY;

    this.element.style.left = `${newLeft}px`;
    this.element.style.top = `${newTop}px`;
    this.element.style.right = "auto";

    if (this.onMove) {
      this.onMove(newTop, newLeft);
    }
  }

  _handleMouseUp() {
    this.isDragging = false;
    window.removeEventListener("mousemove", this._onMouseMove);
    window.removeEventListener("mouseup", this._onMouseUp);
    window.removeEventListener("touchmove", this._onTouchMove);
    window.removeEventListener("touchend", this._onTouchEnd);
  }

  cleanup() {
    if (this.element && this.handleSelector) {
      const handle = this.element.querySelector(this.handleSelector);
      if (handle) {
        handle.removeEventListener("mousedown", this._onMouseDown);
        handle.removeEventListener("touchstart", this._onTouchStart);
      }
    }
    window.removeEventListener("mousemove", this._onMouseMove);
    window.removeEventListener("mouseup", this._onMouseUp);
    window.removeEventListener("touchmove", this._onTouchMove);
    window.removeEventListener("touchend", this._onTouchEnd);
  }
}
