import Component from "@glimmer/component";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import type Site from "discourse/models/site";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class StyleguideButton extends Component {
  // TODO(devxp-typescript-pending): `can_see_styleguide` is added to the site
  // payload by a plugin serializer, which the `Site` model cannot declare. Drop
  // this once plugins have a typed way to extend site fields.
  @service declare site: Site & { can_see_styleguide?: boolean };

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
