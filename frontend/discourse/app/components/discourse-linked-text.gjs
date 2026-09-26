import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class DiscourseLinkedText extends Component {
  get translatedText() {
    if (this.args.text) {
      return i18n(this.args.text, this.args.textParams);
    }
  }

  @action
  click(event) {
    if (event.target.tagName.toUpperCase() === "A") {
      this.args.action(this.args.actionParam);
    }

    event.preventDefault();
    event.stopPropagation();
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <span ...attributes {{on "click" this.click}}>{{trustHTML
        this.translatedText
      }}</span>
  </template>
}
