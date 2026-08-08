/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
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

  // Built by hand rather than with a route, because a breadcrumb item can only link to a route
  // without dynamic segments and this one needs the category and section.
  @computed("section")
  get sectionPath() {
    if (this.section) {
      return `/styleguide/${this.section.category}/${this.section.id}`;
    }
  }

  <template>
    <section
      class={{dConcatClass "styleguide-section" this.sectionClass}}
      ...attributes
    >
      <DPageHeader @hideTabs={{true}}>
        <:breadcrumbs>
          <DBreadcrumbsItem
            @path="/styleguide"
            @label={{i18n "styleguide.title"}}
          />

          {{#if this.section}}
            <DBreadcrumbsItem
              @path={{this.sectionPath}}
              @label={{sectionTitle this.section.id}}
            />
          {{/if}}

          {{! Color mode is page chrome rather than an action on this page, so it sits on the
          utility row with the breadcrumb instead of beside the title. }}
          <ToggleColorMode />
        </:breadcrumbs>

        <:title>
          {{#if this.section}}
            {{sectionTitle this.section.id}}
          {{else if this.title}}
            {{i18n this.title}}
          {{/if}}
        </:title>
      </DPageHeader>

      <div class="styleguide-section-contents">
        {{yield}}
      </div>
    </section>
  </template>
}
