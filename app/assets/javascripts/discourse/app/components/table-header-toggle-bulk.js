import TableHeaderToggleComponent from "discourse/components/table-header-toggle";

export default TableHeaderToggleComponent.extend({
  click(e) {
    const self = this;
    const onClick = function (sel, callback) {
      const target = $(e.target).closest(sel);

      if (target.length === 1) {
        callback.apply(self, [target]);
      }
    };

    onClick("button.bulk-select-all", function () {
      $("input.bulk-select:not(:checked)").click();
    });

    onClick("button.bulk-clear-all", function () {
      $("input.bulk-select:checked").click();
    });

    onClick("span.header-contents", function () {
      this.toggleProperties();
    });
  },
});
