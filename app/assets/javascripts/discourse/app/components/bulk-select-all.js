import DButton from "discourse/components/d-button";

export default DButton.extend({
  click() {
    $("input.bulk-select:not(checked)").click();
  },
});
