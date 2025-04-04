import Component from "@ember/component";
import { classNameBindings, tagName } from "@ember-decorators/component";
import computed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import sectionTitle from "discourse/plugins/styleguide/discourse/helpers/section-title";

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

  <template>
    <h1 class="section-title">
      {{#if this.section}}
        {{sectionTitle this.section.id}}
      {{else}}
        {{i18n this.title}}
      {{/if}}
    </h1>

    <div class="styleguide-section-contents">
      {{yield}}
    </div>
  </template>
}
