class VirtualElementFromCaretCoords {
  constructor(caretCoords, offset = [0, 0]) {
    this.caretCoords = caretCoords;
    this.offset = offset;
    this.updateRect();
  }

  updateRect() {
    const [xOffset, yOffset] = this.offset;
    this.rect = {
      top: this.caretCoords.y + yOffset,
      right: this.caretCoords.x,
      bottom: this.caretCoords.y + yOffset,
      left: this.caretCoords.x + xOffset,
      width: 0,
      height: 0,
      x: this.caretCoords.x,
      y: this.caretCoords.y,
      toJSON() {
        return this;
      },
    };
    return this.rect;
  }

  getBoundingClientRect() {
    return this.rect;
  }

  getClientRects() {
    return [this.rect];
  }

  get clientWidth() {
    return this.rect.width;
  }

  get clientHeight() {
    return this.rect.height;
  }
}

export default function virtualElementFromCaretCoords(caretCoords, offset) {
  return new VirtualElementFromCaretCoords(caretCoords, offset);
}
