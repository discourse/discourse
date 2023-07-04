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
    // a 2x2 grid looks better in most cases for 2 or 4 items
    if (this.items.length === 4 || this.items.length === 2) {
      return 2;
    }
    return this.options.columns;
  }

  render() {
    if (this.container.dataset.columns) {
      return;
    }

    this.container.dataset.columns = this.count();

    const columns = this._distributeEvenly();

    while (this.container.firstChild) {
      this.container.removeChild(this.container.firstChild);
    }
    this.container.append(...columns);
    return this;
  }

  _prepareColumns(count) {
    const columns = [];
    [...Array(count)].forEach(() => {
      const column = document.createElement("div");
      column.classList.add("d-image-grid-column");
      columns.push(column);
    });

    return columns;
  }

  _prepareItems() {
    let targets = [];

    Array.from(this.container.children).forEach((child) => {
      if (child.nodeName === "P" && child.children.length > 0) {
        // sometimes children are wrapped in a paragraph
        Array.from(child.children).forEach((c) => {
          targets.push(this._wrapDirectImage(c));
        });
      } else {
        targets.push(this._wrapDirectImage(child));
      }
    });

    return targets.filter((item) => {
      return !["BR", "P"].includes(item.nodeName);
    });
  }

  _wrapDirectImage(item) {
    if (item.nodeName !== "IMG") {
      return item;
    }

    const wrapper = document.createElement("span");
    wrapper.classList.add("image-wrapper");
    wrapper.append(item);
    return wrapper;
  }

  _distributeEvenly() {
    const count = this.count();
    const columns = this._prepareColumns(count);

    const columnHeights = [];
    for (let n = 0; n < count; n++) {
      columnHeights[n] = 0;
    }
    this.items.forEach((item) => {
      let shortest = 0;

      for (let j = 1; j < count; ++j) {
        if (columnHeights[j] < columnHeights[shortest]) {
          shortest = j;
        }
      }

      // use aspect ratio to compare heights and append to shortest column
      // if element is not an image, assume ratio is 1:1
      const img = item.querySelector("img") || item;
      const aR = img.nodeName === "IMG" ? img.height / img.width : 1;
      columnHeights[shortest] += aR;
      columns[shortest].append(item);
    });

    return columns;
  }
}
