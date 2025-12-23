/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("span")
export default class DiscourseLinkedText extends Component {
  @computed("text", "textParams")
  get translatedText() {
    if (this.text) {
      return i18n(...arguments);
    }
  }

  click(event) {
    if (event.target.tagName.toUpperCase() === "A") {
      this.action(this.actionParam);
    }

    return false;
  }

  <template>{{htmlSafe this.translatedText}}</template>
}
