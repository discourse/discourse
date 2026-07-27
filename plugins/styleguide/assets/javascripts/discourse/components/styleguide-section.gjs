/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ToggleColorMode from "discourse/plugins/styleguide/discourse/components/toggle-color-mode";
import sectionTitle from "discourse/plugins/styleguide/discourse/helpers/section-title";

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
      <div class="styleguide-section__header">
        <h1 class="section-title">
          {{#if this.section}}
            {{sectionTitle this.section.id}}
          {{else}}
            {{i18n this.title}}
          {{/if}}
        </h1>

        <ToggleColorMode />
      </div>

      <div class="styleguide-section-contents">
        {{yield}}
      </div>
    </section>
  </template>
}
