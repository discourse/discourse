import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

class A11ySkipLinksContainer extends Component {
  @service a11y;

  <template>
    {{#if this.a11y.showSkipLinks}}
      <div
        id="skip-links__container"
        class="skip-links"
        aria-label={{i18n "skip_links_label"}}
      >
        <div>
          {{! wrapper used to render the skip links }}
        </div>
        <a href="#main-container" class="skip-link">
          {{i18n "skip_to_main_content"}}
        </a>
      </div>
    {{/if}}
  </template>
}

export default class A11ySkipLinks extends Component {
  static Container = A11ySkipLinksContainer;

  @service a11y;

  wrapperElement = document.querySelector("#skip-links__container > div");

  <template>
    {{#if this.a11y.showSkipLinks}}
      {{#in-element this.wrapperElement insertAfter=null}}
        {{yield}}
      {{/in-element}}
    {{/if}}
  </template>
}
