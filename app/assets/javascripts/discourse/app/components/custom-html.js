import Component from "@ember/component";
import { getCustomHTML } from "discourse/helpers/custom-html";
import { getOwner } from "discourse-common/lib/get-owner";
import deprecated from "discourse-common/lib/deprecated";

export default Component.extend({
  triggerAppEvent: null,

  init() {
    this._super(...arguments);
    const name = this.name;
    const html = getCustomHTML(name);

    if (html) {
      this.set("html", html);
      this.set("layoutName", "components/custom-html-container");
    } else {
      const template = getOwner(this).lookup(`template:${name}`);
      if (template) {
        deprecated(
          "Defining an hbs template for CustomHTML rendering is deprecated. Use plugin outlets instead.",
          { id: "discourse.custom_html_template" }
        );
        this.set("layoutName", name);
      }
    }
  },

  didInsertElement() {
    this._super(...arguments);
    if (this.triggerAppEvent === "true") {
      this.appEvents.trigger(`inserted-custom-html:${this.name}`);
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    if (this.triggerAppEvent === "true") {
      this.appEvents.trigger(`destroyed-custom-html:${this.name}`);
    }
  },
});
