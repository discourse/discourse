import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ToggleColorMode from "discourse/plugins/styleguide/discourse/components/toggle-color-mode";
import sectionTitle from "discourse/plugins/styleguide/discourse/helpers/section-title";

export default class StyleguideSection extends Component {
  scrollToTop = modifier((element, [section, title]) => {
    if (section || title) {
      window.scrollTo(0, 0);
    }
  });

  get sectionClass() {
    if (this.args.section) {
      return `${this.args.section.id}-examples`;
    }
  }

  // Built by hand rather than with a route, because a breadcrumb item can only link to a route
  // without dynamic segments and this one needs the category and section.
  get sectionPath() {
    if (this.args.section) {
      return `/styleguide/${this.args.section.category}/${this.args.section.id}`;
    }
  }

  <template>
    <section
      class={{dConcatClass "styleguide-section" this.sectionClass}}
      ...attributes
      {{this.scrollToTop @section @title}}
    >
      <DPageHeader @hideTabs={{true}}>
        <:breadcrumbs>
          <DBreadcrumbsItem
            @label={{i18n "styleguide.title"}}
            @path="/styleguide"
          />

          {{#if @section}}
            <DBreadcrumbsItem
              @label={{sectionTitle @section.id}}
              @path={{this.sectionPath}}
            />
          {{/if}}

          {{! Color mode is page chrome rather than an action on this page, so it sits on the
          utility row with the breadcrumb instead of beside the title. }}
          <ToggleColorMode />
        </:breadcrumbs>

        <:title>
          {{#if @section}}
            {{sectionTitle @section.id}}
          {{else if @title}}
            {{i18n @title}}
          {{/if}}
        </:title>
      </DPageHeader>

      <div class="styleguide-section-contents">
        {{yield}}
      </div>
    </section>
  </template>
}
