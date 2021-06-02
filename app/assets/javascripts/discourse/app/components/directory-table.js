import Component from "@ember/component";

export default Component.extend({
  classNames: ["directory-table-container"],

  setActiveHeader(id) {
    // After render, scroll table left to ensure the order by column is visible
    const headerEl = document.getElementById(id);
    const tableContainer = document.querySelector(".directory-table-container");
    const scrollPixels =
      headerEl.offsetParent.offsetLeft +
      headerEl.offsetWidth +
      10 -
      tableContainer.offsetWidth;
    if (scrollPixels > 0) {
      tableContainer.scrollLeft = scrollPixels;
    }
  },
});
