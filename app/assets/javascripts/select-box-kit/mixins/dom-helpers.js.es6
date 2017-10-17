export default Ember.Mixin.create({
  init() {
    this._super();

    this.offscreenInputSelector = ".select-box-kit-offscreen";
    this.filterInputSelector = ".select-box-kit-filter-input";
    this.rowSelector = ".select-box-kit-row";
    this.collectionSelector = ".select-box-kit-collection";
    this.headerSelector = ".select-box-kit-header";
    this.bodySelector = ".select-box-kit-body";
  },

  $findRowByValue(value) {
    return this.$(`${this.rowSelector}[data-value='${value}']`);
  },

  $header() {
    return this.$(this.headerSelector);
  },

  $body() {
    return this.$(this.bodySelector);
  },

  $collection() {
    return this.$(this.collectionSelector);
  },

  $rows() {
    return this.$(this.rowSelector);
  },

  $highlightedRow() {
    return this.$rows().filter(".is-highlighted");
  },

  $selectedRow() {
    return this.$rows().filter(".is-selected");
  },

  $offscreenInput() {
    return this.$(this.offscreenInputSelector);
  },

  $filterInput() {
    return this.$(this.filterInputSelector);
  },

  _killEvent(event) {
    event.preventDefault();
    event.stopPropagation();
  }
});
