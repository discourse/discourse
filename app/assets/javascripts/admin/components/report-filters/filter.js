import Component from "@ember/component";
export default Component.extend({
  actions: {
    onChange(value) {
      this.applyFilter(this.get("filter.id"), value);
    }
  }
});
