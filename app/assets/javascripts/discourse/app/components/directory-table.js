import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  classNames: ["directory-table-container"],

  @action
  setActiveHeader(header) {
    // After render, scroll table left to ensure the order by column is visible
    const scrollPixels =
      header.offsetLeft + header.offsetWidth + 10 - this.element.offsetWidth;

    if (scrollPixels > 0) {
      this.element.scrollLeft = scrollPixels;
    }
  },
});
