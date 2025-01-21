import Component from "@ember/component";
import { classNameBindings, tagName } from "@ember-decorators/component";
import computed from "discourse/lib/decorators";

@tagName("section")
@classNameBindings(":styleguide-section", "sectionClass")
export default class StyleguideSection extends Component {
  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    window.scrollTo(0, 0);
  }

  @computed("section")
  sectionClass(section) {
    if (section) {
      return `${section.id}-examples`;
    }
  }
}
