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
        <a href="#main-container" class="skip-link">
          {{i18n "skip_to_main_content"}}
        </a>
      </div>
    {{/if}}
  </template>
}

class A11ySkipLinksWrapper extends Component {
  wrapperElement;

  constructor() {
    super(...arguments);

    // the element is created manually to render all the items in one phase
    const element = document.createElement("div");
    const container = document.querySelector("#skip-links__container");

    // prepend the wrapper to the container
    container.prepend(element);
    this.wrapperElement = element;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.wrapperElement.remove();
    this.wrapperElement = null;
  }

  <template>
    {{#in-element this.wrapperElement}}
      {{yield}}
    {{/in-element}}
  </template>
}

export default class A11ySkipLinks extends Component {
  static Container = A11ySkipLinksContainer;

  @service a11y;

  <template>
    {{#if this.a11y.showSkipLinks}}
      {{! the nested wrapping will force the wrapper elements to be recreated when `showSkipLinks` changes }}
      <A11ySkipLinksWrapper>{{yield}}</A11ySkipLinksWrapper>
    {{/if}}
  </template>
}
