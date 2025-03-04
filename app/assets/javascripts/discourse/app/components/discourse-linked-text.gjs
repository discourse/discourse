import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import htmlSafe from "discourse/helpers/html-safe";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

@tagName("span")
export default class DiscourseLinkedText extends Component {
  <template>
    {{htmlSafe this.translatedText}}
  </template>

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
}
