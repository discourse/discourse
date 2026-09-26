import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SiteService from "discourse/services/site";

export default class StyleguideButton extends Component {
  @service(() => SiteService) site;

  <template>
    {{#if this.site.can_see_styleguide}}
      <a
        aria-label={{i18n "dev_tools.open_styleguide"}}
        class="dev-tools-toolbar__link open-styleguide"
        data-auto-route="true"
        href={{getURL "/styleguide"}}
        title={{i18n "dev_tools.open_styleguide"}}
      >
        {{dIcon "paintbrush"}}
      </a>
    {{/if}}
  </template>
}
