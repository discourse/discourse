import Component from "@ember/component";

export default Component.extend({
  tagName: "",

  actions: {
    onChange(tags) {
      this.set("value", tags);

      this.valueChanged &&
        this.valueChanged({
          target: {
            value: tags,
          },
        });
    },
  },
});
