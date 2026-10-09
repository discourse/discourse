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

  // TODO (ui-kit-reorderable-list-cleanup) the members from here to
  // `onDragEnd` serve the pre-DReorderableList consumers only. Delete them
  // with the legacy arms; `reorderVisible` is the replacement.
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

  /**
   * Adopts a new order for the enabled keys that are currently on screen.
   *
   * A search filter can hide an enabled row, and a hidden row still holds its
   * place in the saved order. So the visible keys are written back into the
   * slots they already occupy and every hidden key keeps its index, rather than
   * the caller's on-screen sequence replacing the whole order and dropping
   * whatever it could not see.
   *
   * @param {string[]} visibleKeys - Enabled keys in their new on-screen order.
   */
  reorderVisible(visibleKeys) {
    const moving = new Set(visibleKeys);
    let next = 0;
    this.enabledOrder = this.enabledOrder.map((key) =>
      moving.has(key) ? visibleKeys[next++] : key
    );
  }
}
