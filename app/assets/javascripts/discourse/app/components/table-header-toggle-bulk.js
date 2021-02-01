import TableHeaderToggleComponent from "discourse/components/table-header-toggle";

export default TableHeaderToggleComponent.extend({
  click(e) {
    const onClick = (sel, callback) => {
      const target = $(e.target).closest(sel);

      if (target.length === 1) {
        callback.apply(this, [target]);
      }
    };

    onClick("button.bulk-select-all", () => {
      $("input.bulk-select:not(:checked)").click();
    });

    onClick("button.bulk-clear-all", () => {
      $("input.bulk-select:checked").click();
    });

    onClick("span.header-contents", () => {
      this.toggleProperties();
    });
  },
});
