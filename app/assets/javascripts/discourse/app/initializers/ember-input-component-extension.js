import TextSupport from "@ember/views/text-support";

export default {
  name: "ember-input-component-extensions",

  initialize() {
    TextSupport.reopen({
      attributeBindings: ["aria-describedby", "aria-invalid"],
    });
  },
};
