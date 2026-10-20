import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import lazyHash from "discourse/helpers/lazy-hash";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.showWarningsWarning}}
    <div class="alert alert-info">{{trustHTML
        (i18n "admin.user.warnings_list_warning")
      }}</div>
  {{/if}}

  <MessagesSecondaryNav>
    <DNavigationItem
      class="user-nav__messages-latest"
      @ariaCurrentContext="subNav"
      @route="userPrivateMessages.user.index"
    >
      {{dIcon "envelope"}}
      <span>{{i18n "categories.latest"}}</span>
    </DNavigationItem>

    <DNavigationItem
      class="user-nav__messages-sent"
      @ariaCurrentContext="subNav"
      @route="userPrivateMessages.user.sent"
    >
      {{dIcon "reply"}}
      <span>{{i18n "user.messages.sent"}}</span>
    </DNavigationItem>

    {{#if @controller.viewingSelf}}
      <DNavigationItem
        class="user-nav__messages-new"
        @ariaCurrentContext="subNav"
        @route="userPrivateMessages.user.new"
      >
        {{dIcon "circle-exclamation"}}
        <span>{{@controller.newLinkText}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__messages-unread"
        @ariaCurrentContext="subNav"
        @route="userPrivateMessages.user.unread"
      >
        {{dIcon "circle-plus"}}
        <span>{{@controller.unreadLinkText}}</span>
      </DNavigationItem>
    {{/if}}

    <DNavigationItem
      class="user-nav__messages-archive"
      @ariaCurrentContext="subNav"
      @route="userPrivateMessages.user.archive"
    >
      {{dIcon "box-archive"}}
      <span>{{i18n "user.messages.archive"}}</span>
    </DNavigationItem>

    <PluginOutlet
      @name="user-messages-nav-bottom"
      @outletArgs={{lazyHash
        viewingSelf=@controller.viewingSelf
        model=@controller.model
      }}
    />
  </MessagesSecondaryNav>

  {{outlet}}
</template>
