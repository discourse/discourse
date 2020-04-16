import Component from "@ember/component";
export default Component.extend({
  actions: {
    onChange(value) {
      this.applyFilter(this.filter.id, value);
    }
  }
});
