import Component from "@ember/component";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@classNames("conditional-loading-section")
@classNameBindings("isLoading")
export default class ConditionalLoadingSection extends Component {
  isLoading = false;
  title = i18n("conditional_loading_section.loading");

  <template>
    {{#if this.isLoading}}
      <span class="title">{{this.title}}</span>
      <div class="spinner {{this.size}}"></div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
