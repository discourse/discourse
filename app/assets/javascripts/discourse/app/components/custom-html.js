import Component from "@ember/component";
import { getOwner } from "@ember/owner";
import { hbs } from "ember-cli-htmlbars";
import { getCustomHTML } from "discourse/helpers/custom-html";
import deprecated from "discourse/lib/deprecated";

export default class CustomHtml extends Component {
  triggerAppEvent = null;

  init() {
    super.init(...arguments);
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
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    if (this.triggerAppEvent === "true") {
      this.appEvents.trigger(`inserted-custom-html:${this.name}`);
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    if (this.triggerAppEvent === "true") {
      this.appEvents.trigger(`destroyed-custom-html:${this.name}`);
    }
  }
}
