import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class BoostsPreferences extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.discourse_boosts_enabled;
  }

  <template>
    <li class="user-nav__preferences-boosts">
      <LinkTo @route="preferences.boosts">
        {{icon "rocket"}}
        <span>{{i18n "discourse_boosts.boosts_title"}}</span>
      </LinkTo>
    </li>
  </template>
}
