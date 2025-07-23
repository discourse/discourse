import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AutoImageCaptionSetting extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.discourse_ai_enabled;
  }

  <template>
    <li class="user-nav__preferences-ai">
      <LinkTo @route="preferences.ai">
        {{icon "discourse-sparkles"}}
        <span>{{i18n "discourse_ai.title"}}</span>
      </LinkTo>
    </li>
  </template>
}
