/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

@tagName("")
export default class DConditionalLoadingSection extends Component {
  isLoading = false;
  title = i18n("conditional_loading_section.loading");

  <template>
    <div
      class={{dConcatClass
        "conditional-loading-section"
        (if this.isLoading "is-loading")
      }}
      ...attributes
    >
      {{#if this.isLoading}}
        <span class="title">{{this.title}}</span>
        <div class="spinner {{this.size}}"></div>
      {{else}}
        {{yield}}
      {{/if}}
    </div>
  </template>
}
