import { LinkTo } from "@ember/routing";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import { i18n } from "discourse-i18n";

const ChatRoutesChannelInfoNav = <template>
  {{#if @channel.isOpen}}
    <div class="c-channel-info__nav">
      <DHorizontalOverflowNav
        class="nav"
        @ariaLabel={{i18n "chat.channel_info.nav_label"}}
      >
        {{#if @channel.currentUserMembership.following}}
          <li>
            <LinkTo
              class={{if (eq @tab "preferences") "active"}}
              @models={{@channel.routeModels}}
              @replace={{true}}
              @route="chat.channel.info.preferences"
            >
              {{i18n "chat.channel_info.tabs.preferences"}}
            </LinkTo>
          </li>
        {{/if}}
        <li>
          <LinkTo
            class={{if (eq @tab "settings") "active"}}
            @models={{@channel.routeModels}}
            @replace={{true}}
            @route="chat.channel.info.settings"
          >
            {{i18n "chat.channel_info.tabs.settings"}}
          </LinkTo>
        </li>
        <li>
          <LinkTo
            class={{if (eq @tab "members") "active"}}
            @models={{@channel.routeModels}}
            @replace={{true}}
            @route="chat.channel.info.members"
          >
            {{i18n "chat.channel_info.tabs.members"}}
            {{#if @channel.isCategoryChannel}}
              <span
                class="c-channel-info__member-count"
              >({{@channel.membershipsCount}})</span>
            {{/if}}
          </LinkTo>
        </li>
      </DHorizontalOverflowNav>
    </div>
  {{/if}}
</template>;

export default ChatRoutesChannelInfoNav;
