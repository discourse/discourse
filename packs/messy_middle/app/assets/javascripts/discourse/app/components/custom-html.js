import Component from "@ember/component";
import { getCustomHTML } from "discourse/helpers/custom-html";
import { getOwner } from "discourse-common/lib/get-owner";
import { hbs } from "ember-cli-htmlbars";
import deprecated from "discourse-common/lib/deprecated";

export default Component.extend({
  triggerAppEvent: null,

  init() {
    this._super(...arguments);
    const name = this.name;
    const html = getCustomHTML(name);

    if (html) {
      this.set("html", html);
      this.set("layout", hbs`{{this.html}}`);
    } else {
      const template = getOwner(this).lookup(`template:${name}`);
      if (template) {
        deprecated(
          "Defining an hbs template for CustomHTML rendering is deprecated. Use plugin outlets instead.",
          { id: "discourse.custom_html_template" }
        );
        this.set("layout", template);
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
