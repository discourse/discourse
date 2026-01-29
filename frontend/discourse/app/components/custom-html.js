import Component from "@glimmer/component";
import { hbs } from "ember-cli-htmlbars";
import { getCustomHTML } from "discourse/helpers/custom-html";

export default class CustomHtml extends Component {
  triggerAppEvent = null;

  init() {
    super.init(...arguments);
    const name = this.name;
    const html = getCustomHTML(name);

    if (html) {
      this.set("html", html);
      this.set("layout", hbs`{{this.html}}`);
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
