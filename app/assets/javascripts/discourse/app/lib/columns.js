// Inspired by https://github.com/mladenilic/columns.js
// TODO: add more details

export default class Columns {
  constructor(container, options = {}) {
    this.container = container;

    this.options = {
      columns: 2,
      columnClass: "d-image-grid-column",
      minCount: 2,
      ...options,
    };

    this.excluded = ["BR", "P"];

    this.items = this._prepareItems();

    if (this.items.length >= this.options.minCount) {
      this.render();
    } else {
      container.classList.add("d-image-grid-disabled");
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
    const count = this.count();
    const columns = this._prepareColumns(count);

    this.items.forEach((item, index) => {
      columns[index % count].append(item);
    });

    this.container.dataset.columns = count;
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

    // sometimes the children are wrapped in a paragraph
    if (targets.length === 1 && targets[0].nodeName === "P") {
      targets = targets[0].children;
    }

    return Array.from(targets).filter((item) => {
      return !this.excluded.includes(item.nodeName);
    });
  }
}
