import TextField from "@ember/component/text-field";
import TextArea from "@ember/component/text-area";
let initializedOnce = false;

export default {
  name: "ember-input-component-extensions",

  initialize() {
    if (initializedOnce) {
      return;
    }

    TextField.reopen({
      attributeBindings: ["aria-describedby", "aria-invalid"],
    });
    TextArea.reopen({
      attributeBindings: ["aria-describedby", "aria-invalid"],
    });

    initializedOnce = true;
  },
};
