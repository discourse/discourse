/**
 * Turns an element containing multiple children into a grid of columns.
 * Can be used to arrange images or media in a grid.
 *
 * Inspired/adapted from https://github.com/mladenilic/columns.js
 *
 */
export default class Columns {
  constructor(container, options = {}) {
    this.container = container;

    this.options = {
      columns: 3,
      minCount: 2,
      ...options,
    };

    this.items = this._prepareItems();

    if (this.items.length >= this.options.minCount) {
      this.render();
    } else {
      container.dataset.disabled = true;
    }
  }

  count() {
    // 2x2 grid looks better for 2 or 4 items
    return [2, 4].includes(this.items.length) ? 2 : this.options.columns;
  }

  render() {
    if (this.container.dataset.columns) {
      return;
    }

    this.container.dataset.columns = this.count();
    this.container.replaceChildren(...this._distributeEvenly());

    return this;
  }

  _prepareColumns(count) {
    return [...Array(count)].map(() => {
      const column = document.createElement("div");
      column.classList.add("d-image-grid-column");
      return column;
    });
  }

  _prepareItems() {
    let targets = [];

    const children = [...this.container.children];
    for (let child of children) {
      // sometimes children are wrapped in a paragraph
      if (child.nodeName === "P" && child.children.length > 0) {
        for (let c of [...child.children]) {
          if (!["BR", "P"].includes(c.nodeName)) {
            targets.push(c);
          }
        }
      } else {
        if (!["BR", "P"].includes(child.nodeName)) {
          targets.push(child);
        }
      }
    }

    return targets;
  }

  _wrapDirectImage(item) {
    if (["BR", "P"].includes(item.nodeName)) {
      return null;
    }

    if (item.nodeName !== "IMG") {
      // If it's already a lightbox wrapper, return it as is
      if (
        item.classList.contains("lightbox-wrapper") ||
        item.classList.contains("lightbox")
      ) {
        return item;
      }
      return item;
    }

    const wrapper = document.createElement("span");
    wrapper.classList.add("image-wrapper");
    // Move the original node to preserve listeners
    wrapper.appendChild(item);
    return wrapper;
  }

  _distributeEvenly() {
    const count = this.count();
    const columns = this._prepareColumns(count);
    const heights = Array(count).fill(0);

    this.items.forEach((item) => {
      let shortest = 0;

      for (let j = 1; j < count; ++j) {
        if (heights[j] < heights[shortest]) {
          shortest = j;
        }
      }

      // use aspect ratio to compare heights and append to shortest column
      // if element is not an image, assume ratio is 1:1
      const img =
        item.querySelector("img") || (item.nodeName === "IMG" ? item : null);
      heights[shortest] += img && img.width > 0 ? img.height / img.width : 1;

      const wrappedItem = this._wrapDirectImage(item);
      columns[shortest].append(wrappedItem);
    });

    return columns;
  }
}
