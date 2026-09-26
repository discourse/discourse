import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import { i18n } from "discourse-i18n";
import A11yService from "discourse/services/a11y";

class A11ySkipLinksContainer extends Component {
  @service(() => A11yService) a11y;

  <template>
    {{#if this.a11y.showSkipLinks}}
      <div
        aria-label={{i18n "skip_links_label"}}
        class="skip-links"
        id="skip-links__container"
      >
        <div>
          {{! wrapper used to render the skip links }}
        </div>
        <a class="skip-link" href="#main-container">
          {{i18n "skip_to_main_content"}}
        </a>
      </div>
    {{/if}}
  </template>
}

export default class A11ySkipLinks extends Component {
  static Container = A11ySkipLinksContainer;

  @service(() => A11yService) a11y;

  wrapperElement = document.querySelector("#skip-links__container > div");

  <template>
    {{#if this.a11y.showSkipLinks}}
      {{#in-element this.wrapperElement insertAfter=null}}
        {{yield}}
      {{/in-element}}
    {{/if}}
  </template>
}
