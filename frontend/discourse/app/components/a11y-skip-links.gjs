import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import concatClass from "../helpers/concat-class";

export default class A11ySkipLinks extends Component {
  @service a11ySkipLinks;

  <template>
    {{#if this.a11ySkipLinks.show}}
      <div class="skip-links" aria-label={{i18n "skip_links_label"}}>
        {{#each this.a11ySkipLinks.items key="id" as |skipLink|}}
          <a
            href={{skipLink.href}}
            class={{concatClass "skip-link" skipLink.classNames}}
            {{(if skipLink.onClick (modifier on "click" skipLink.onClick))}}
          >
            {{skipLink.label}}
          </a>
        {{/each}}
        <a href="#main-container" class="skip-link">
          {{i18n "skip_to_main_content"}}
        </a>
      </div>
    {{/if}}
  </template>
}
