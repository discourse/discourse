import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";
import EmberObject, { action } from "@ember/object";
import { extractError } from "discourse/lib/ajax-error";
import { reload } from "discourse/helpers/page-reloader";

const UP = "up";
const DOWN = "down";

export default Modal.extend({
  loading: true,
  columns: null,
  labelKey: null,

  onShow() {
    ajax("edit-directory-columns.json")
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

    ajax("edit-directory-columns.json", { type: "PUT", data })
      .then(() => {
        reload();
      })
      .catch((e) => {
        this.set("loading", false);
        this.flash(extractError(e), "error");
      });
  },

  @action
  resetToDefault() {
    let resetColumns = this.columns;
    resetColumns
      .sort((a, b) =>
        (a.automatic_position || a.user_field.position + 1000) >
        (b.automatic_position || b.user_field.position + 1000)
          ? 1
          : -1
      )
      .forEach((column, index) => {
        column.setProperties({
          position: column.automatic_position || index + 1,
          enabled: column.type === "automatic",
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
