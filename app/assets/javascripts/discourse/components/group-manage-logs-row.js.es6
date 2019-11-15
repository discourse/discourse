import Component from "@ember/component";
export default Component.extend({
  tagName: "",
  expandDetails: false,

  actions: {
    toggleDetails() {
      this.toggleProperty("expandDetails");
    },

    filter(params) {
      this.set(`filters.${params.key}`, params.value);
    }
  }
});
