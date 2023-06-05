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
      columnClass: "d-image-grid-column",
      minCount: 2,
      ...options,
    };

    this.excluded = ["BR", "P"];

    this.items = this._prepareItems();

    if (this.items.length >= this.options.minCount) {
      this.render();
    } else {
      container.dataset.disabled = true;
    }
  }

  count() {
    // a 2x2 grid looks better for 2 or 4 items
    if (this.items.length === 4 || this.items.length === 2) {
      return 2;
    }
    return this.options.columns;
  }

  render() {
    if (this.container.dataset.columns) {
      return;
    }

    const columns = this._allItemsAreImages()
      ? this._distributeEvenly()
      : this._distributeInOrder();

    this.container.dataset.columns = this.count();

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
      column.classList.add(this.options.columnClass);
      columns.push(column);
    });

    return columns;
  }

  _prepareItems() {
    let targets = this.container.children;

    // if all children are wrapped in a paragraph, pull them out
    if (targets.length === 1 && targets[0].nodeName === "P") {
      targets = targets[0].children;
    }

    return Array.from(targets).filter((item) => {
      return !this.excluded.includes(item.nodeName);
    });
  }

  _allItemsAreImages() {
    return this.items.every(
      (item) => item.querySelector("img") || item.nodeName === "IMG"
    );
  }

  _distributeEvenly() {
    const count = this.count();
    const columns = this._prepareColumns(count);

    const columnHeights = [];
    for (let n = 0; n < count; n++) {
      columnHeights[n] = 0;
    }
    this.items.forEach((item) => {
      const img = item.querySelector("img") || item;
      let shortest = 0;

      for (let j = 1; j < count; ++j) {
        if (columnHeights[j] < columnHeights[shortest]) {
          shortest = j;
        }
      }

      // use aspect ratio to compare image heights
      columnHeights[shortest] += (img.height / img.width) * 100;
      columns[shortest].append(item);
    });

    return columns;
  }

  _distributeInOrder() {
    const count = this.count();
    const columns = this._prepareColumns(count);

    this.items.forEach((item, index) => {
      columns[index % count].append(item);
    });

    return columns;
  }
}
