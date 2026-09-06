import { tracked } from "@glimmer/tracking";

export default class ToggleableOrderedList {
  @tracked enabledOrder;
  @tracked draggedId = null;

  constructor({ cap, minSelected = 0, initialOrder = [] } = {}) {
    this.cap = cap;
    this.minSelected = minSelected;
    this.enabledOrder = [...initialOrder];
  }

  get enabledKeys() {
    return new Set(this.enabledOrder);
  }

  get atCap() {
    return this.cap != null && this.enabledOrder.length >= this.cap;
  }

  get reorderable() {
    return this.enabledOrder.length > 1;
  }

  isEnabled(key) {
    return this.enabledKeys.has(key);
  }

  toggleDisabled(key) {
    if (this.isEnabled(key)) {
      return this.enabledOrder.length <= this.minSelected;
    }
    return this.atCap;
  }

  toggle(key) {
    if (this.isEnabled(key)) {
      if (this.enabledOrder.length <= this.minSelected) {
        return;
      }
      this.enabledOrder = this.enabledOrder.filter((k) => k !== key);
    } else if (!this.atCap) {
      this.enabledOrder = [...this.enabledOrder, key];
    }
  }

  moveUp(key) {
    const index = this.enabledOrder.indexOf(key);
    if (index <= 0) {
      return;
    }
    const next = [...this.enabledOrder];
    [next[index - 1], next[index]] = [next[index], next[index - 1]];
    this.enabledOrder = next;
  }

  moveDown(key) {
    const index = this.enabledOrder.indexOf(key);
    if (index < 0 || index === this.enabledOrder.length - 1) {
      return;
    }
    const next = [...this.enabledOrder];
    [next[index], next[index + 1]] = [next[index + 1], next[index]];
    this.enabledOrder = next;
  }

  onDragStart(key) {
    this.draggedId = key;
  }

  onDrop(targetKey, dropAbove) {
    const fromIndex = this.enabledOrder.indexOf(this.draggedId);
    this.draggedId = null;
    if (fromIndex < 0) {
      return;
    }

    const targetIndex = this.enabledOrder.indexOf(targetKey);
    if (targetIndex < 0) {
      return;
    }

    let toIndex = dropAbove ? targetIndex : targetIndex + 1;
    if (fromIndex < toIndex) {
      toIndex -= 1;
    }
    if (fromIndex === toIndex) {
      return;
    }

    const next = [...this.enabledOrder];
    const [moved] = next.splice(fromIndex, 1);
    next.splice(toIndex, 0, moved);
    this.enabledOrder = next;
  }

  onDragEnd() {
    this.draggedId = null;
  }
}
