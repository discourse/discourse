/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

@tagName("")
export default class StyleguideSection extends Component {
  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    window.scrollTo(0, 0);
  }

  @computed("section")
  get sectionClass() {
    if (this.section) {
      return `${this.section.id}-examples`;
    }
  }

  <template>
    <section
      class={{dConcatClass "styleguide-section" this.sectionClass}}
      ...attributes
    >
      <div class="styleguide-section-contents">
        {{yield}}
      </div>
    </section>
  </template>
}
