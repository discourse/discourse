import TextField from "@ember/component/text-field";
import TextArea from "@ember/component/text-area";

export default {
  name: "ember-input-component-extensions",

  initialize() {
    TextField.reopen({
      attributeBindings: ["aria-describedby", "aria-invalid"],
    });
    TextArea.reopen({
      attributeBindings: ["aria-describedby", "aria-invalid"],
    });
  },
};
