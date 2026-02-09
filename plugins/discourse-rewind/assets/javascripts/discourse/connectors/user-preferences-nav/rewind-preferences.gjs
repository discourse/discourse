import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class RewindPreferencesNav extends Component {
  static shouldRender(args, context, owner) {
    const rewind = owner.lookup("service:rewind");

    // This uses the rewind site setting rather than rewind.active
    // from the service because if the user disables rewind,
    // the preferences tab will disappear forever.
    return context.siteSettings.discourse_rewind_enabled && rewind.active;
  }

  <template>
    <li class="user-nav__preferences-rewind">
      <LinkTo @route="preferences.rewind">
        {{icon "repeat"}}
        <span>{{i18n "discourse_rewind.title"}}</span>
      </LinkTo>
    </li>
  </template>
}
