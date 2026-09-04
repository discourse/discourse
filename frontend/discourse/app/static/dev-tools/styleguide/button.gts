import Component from "@glimmer/component";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class StyleguideButton extends Component {
  @service site;

  <template>
    {{#if this.site.can_see_styleguide}}
      <a
        href={{getURL "/styleguide"}}
        title={{i18n "dev_tools.open_styleguide"}}
        aria-label={{i18n "dev_tools.open_styleguide"}}
        class="dev-tools-toolbar__link open-styleguide"
        data-auto-route="true"
      >
        {{dIcon "paintbrush"}}
      </a>
    {{/if}}
  </template>
}
