class VirtualElementFromTextRange {
  constructor() {
    this.updateRect();
  }

  updateRect() {
    const selection = document.getSelection();

    this.range = selection?.rangeCount && selection?.getRangeAt?.(0);

    if (!this.range) {
      return;
    }

    // Create a fake element if range is collapsed
    if (this.range.collapsed) {
      const tempSpan = document.createElement("span");
      tempSpan.textContent = "\u200B"; // Zero-width space
      this.range.insertNode(tempSpan);
      this.rect = tempSpan.getBoundingClientRect();
      tempSpan.parentNode.removeChild(tempSpan);
    } else {
      this.rect = this.range.getBoundingClientRect();
    }

    return this.rect;
  }

  getBoundingClientRect() {
    return this.rect;
  }

  getClientRects() {
    return this.range.getClientRects();
  }

  get clientWidth() {
    return this.rect.width;
  }

  get clientHeight() {
    return this.rect.height;
  }
}

export default function virtualElementFromTextRange() {
  return new VirtualElementFromTextRange();
}
