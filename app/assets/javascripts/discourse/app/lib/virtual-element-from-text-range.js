class VirtualElementFromTextRange {
  constructor() {
    this.updateRect();
  }

  updateRect() {
    const selection = document.getSelection();
    this.range = selection && selection.rangeCount && selection.getRangeAt(0);
    this.rect = this.range.getBoundingClientRect();
    return this.rect;
  }

  getBoundingClientRect() {
    return this.rect;
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
