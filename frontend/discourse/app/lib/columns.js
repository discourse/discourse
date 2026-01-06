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
    if (item.nodeName !== "IMG") {
      return item;
    }

    const wrapper = document.createElement("span");
    wrapper.classList.add("image-wrapper");
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

      const img =
        item.querySelector("img") || (item.nodeName === "IMG" ? item : null);
      heights[shortest] += img && img.width > 0 ? img.height / img.width : 1;

      const wrappedItem = this._wrapDirectImage(item);
      columns[shortest].append(wrappedItem);
    });

    return columns;
  }
}
