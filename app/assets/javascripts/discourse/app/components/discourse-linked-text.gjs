import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

@tagName("span")
export default class DiscourseLinkedText extends Component {
  @discourseComputed("text", "textParams")
  translatedText(text) {
    if (text) {
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
