export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-filter",
  classNames: "select-box-kit-filter",
  classNameBindings: ["isFocused", "isHidden"],
  isHidden: Ember.computed.not("filterable"),

  actions: {
    onKeyUp(_filter) {
      Ember.run.debounce(this, this._debouncedFilter, _filter, 150);

      // if (!Ember.isEmpty(_filter)) {
      //   this.set("isHidden", false);
      // }
    }
  },

  _debouncedFilter(_filter) { this.get("onFilterChange")(_filter); },
});
