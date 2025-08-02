import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";

export default class ChatRoutesChannelInfoNav extends Component {
  @service site;

  get showTabs() {
    return this.site.desktopView && this.args.channel.isOpen;
  }

  <template>
    <div class="c-routes --channel-info-nav">
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
                {{i18n "chat.channel_info.tabs.settings"}}
              </LinkTo>
            </li>
            <li>
              <LinkTo
                @route="chat.channel.info.members"
                @models={{@channel.routeModels}}
                class={{if (eq @tab "members") "active"}}
                @replace={{true}}
              >
                {{i18n "chat.channel_info.tabs.members"}}
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
    </div>
  </template>
}
