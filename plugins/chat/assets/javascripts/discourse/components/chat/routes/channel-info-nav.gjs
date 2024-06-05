import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import I18n from "discourse-i18n";

export default class ChatRoutesChannelInfoNav extends Component {
  @service site;

  membersLabel = I18n.t("chat.channel_info.tabs.members");
  settingsLabel = I18n.t("chat.channel_info.tabs.settings");

  get showTabs() {
    return this.site.desktopView && this.args.channel.isOpen;
  }

  <template>
    {{#if this.showTabs}}
      <nav class="c-channel-info__nav">
        <ul class="nav nav-pills">
          <li>
            <LinkTo
              @route="chat.channel.info.settings"
              @models={{@channel.routeModels}}
              class={{if (eq @tab "settings") "active"}}
              @replace={{true}}
            >
              {{this.settingsLabel}}
            </LinkTo>
          </li>
          <li>
            <LinkTo
              @route="chat.channel.info.members"
              @models={{@channel.routeModels}}
              class={{if (eq @tab "members") "active"}}
              @replace={{true}}
            >
              {{this.membersLabel}}
              {{#if @channel.isCategoryChannel}}
                <span
                  class="c-channel-info__member-count"
                >({{@channel.membershipsCount}})</span>
              {{/if}}
            </LinkTo>
          </li>
        </ul>
      </nav>
    {{/if}}
  </template>
}
