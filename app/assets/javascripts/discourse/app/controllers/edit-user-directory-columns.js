import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import EmberObject, { action } from "@ember/object";
import { extractError } from "discourse/lib/ajax-error";
import { reload } from "discourse/helpers/page-reloader";

const UP = "up";
const DOWN = "down";

export default Controller.extend(ModalFunctionality, {
  loading: true,
  columns: null,
  labelKey: null,

  onShow() {
    ajax("directory-columns.json")
      .then((response) => {
        this.setProperties({
          loading: false,
          columns: response.directory_columns
            .sort((a, b) => (a.position > b.position ? 1 : -1))
            .map((c) => EmberObject.create(c)),
        });
      })
      .catch(extractError);
  },

  @action
  save() {
    this.set("loading", true);
    const data = {
      directory_columns: this.columns.map((c) =>
        c.getProperties("id", "enabled", "position")
      ),
    };

    ajax("directory-columns.json", { type: "POST", data })
      .then(() => {
        reload();
      })
      .catch(extractError);
  },

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
