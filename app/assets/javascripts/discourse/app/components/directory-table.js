import Component from "@ember/component";
import { action } from "@ember/object";

export default class DirectoryTable extends Component {
  _table = null;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.setProperties({
      _table: this.element.querySelector(".directory-table"),
      _columnCount: this.showTimeRead
        ? this.columns.length + 1
        : this.columns.length,
    });

    this._table.style.gridTemplateColumns = `minmax(15em, 3fr) repeat(${this._columnCount}, minmax(max-content, 1fr))`;
  }

  @action
  setActiveHeader(header) {
    // After render, scroll table left to ensure the order by column is visible
    if (!this._table) {
      this.set("_table", document.querySelector(".directory-table"));
    }
    const scrollPixels =
      header.offsetLeft + header.offsetWidth + 10 - this._table.offsetWidth;

    if (scrollPixels > 0) {
      this._table.scrollLeft = scrollPixels;
    }
  }

  @action
  updateOrder(field, asc) {
    this.setProperties({
      order: field,
      asc,
    });
  }
}
