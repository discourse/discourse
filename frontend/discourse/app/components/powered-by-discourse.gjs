import Component from "@glimmer/component";
import { modifier as modifierFn } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class PoweredByDiscourse extends Component {
  setCssVarHeight = modifierFn((element) => {
    document.documentElement.style.setProperty(
      "--powered-by-height",
      `${element.getBoundingClientRect().height}px`
    );
  });

  <template>
    {{! template-lint-disable link-rel-noopener }}
    <a
      class="powered-by-discourse"
      href="https://discourse.org/powered-by"
      target="_blank"
      {{this.setCssVarHeight}}
    >
      <span class="powered-by-discourse__content">
        <span class="powered-by-discourse__logo">
          {{icon "fab-discourse"}}
        </span>
        <span>{{i18n "powered_by_discourse"}}</span>
      </span>
    </a>
  </template>
}
