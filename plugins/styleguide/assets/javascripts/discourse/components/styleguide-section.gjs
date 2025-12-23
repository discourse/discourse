/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { classNameBindings, tagName } from "@ember-decorators/component";
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
  get sectionClass() {
    if (this.section) {
      return `${this.section.id}-examples`;
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
