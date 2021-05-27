import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import EmberObject, { action } from "@ember/object";
import { extractError } from "discourse/lib/ajax-error";

const UP = "up";
const DOWN = "down";

export default Controller.extend(ModalFunctionality, {
  loading: true,
  columns: null,
  labelKey: null,
  initialJSONStringified: null,

  onShow() {
    ajax("directory-columns.json")
      .then((response) => {
        this.setProperties({
          loading: false,
          columns: response.directory_columns
            .sort((a, b) => (a.position > b.position ? 1 : -1))
            .map((c) => EmberObject.create(c)),
        });
        this.set("initialJSONStringified", JSON.stringify(this.columns));
      })
      .catch(extractError);
  },

  @action
  save() {},

  @action
  resetToDefault() {
    let resetColumns = this.columns;
    resetColumns
      .sort((a, b) =>
        (a.automatic_position || Infinity) > (b.automatic_position || Infinity)
          ? 1
          : -1
      )
      .forEach((column, index) => {
        column.setProperties({
          position: column.automatic_position || index,
          enabled: column.automatic,
        });
      });
    this.set("columns", resetColumns);
    this.notifyPropertyChange("columns");
  },

  @action
  moveUp(column) {
    this._moveColumn(UP, column);
  },

  @action
  moveDown(column) {
    this._moveColumn(DOWN, column);
  },

  _moveColumn(direction, column) {
    if (
      (direction === UP && column.position === 1) ||
      (direction === DOWN && column.position === this.columns.length)
    ) {
      return;
    }

    const positionOnClick = column.position;
    const newPosition =
      direction === UP ? positionOnClick - 1 : positionOnClick + 1;

    const previousColumn = this.columns.find((c) => c.position === newPosition);

    column.set("position", newPosition);
    previousColumn.set("position", positionOnClick);

    this.set(
      "columns",
      this.columns.sort((a, b) => (a.position > b.position ? 1 : -1))
    );
    this.notifyPropertyChange("columns");
  },
});
