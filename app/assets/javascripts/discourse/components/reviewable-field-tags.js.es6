import Component from "@ember/component";

export default Component.extend({
  actions: {
    onChange(tags) {
      this.valueChanged &&
        this.valueChanged({
          target: {
            value: tags
          }
        });
    }
  }
});
