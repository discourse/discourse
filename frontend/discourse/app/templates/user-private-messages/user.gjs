import { trustHTML } from "@ember/template";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
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
      @route="userPrivateMessages.user.index"
      @ariaCurrentContext="subNav"
      class="user-nav__messages-latest"
    >
      {{dIcon "envelope"}}
      <span>{{i18n "categories.latest"}}</span>
    </DNavigationItem>

    <DNavigationItem
      @route="userPrivateMessages.user.sent"
      @ariaCurrentContext="subNav"
      class="user-nav__messages-sent"
    >
      {{dIcon "reply"}}
      <span>{{i18n "user.messages.sent"}}</span>
    </DNavigationItem>

    {{#if @controller.viewingSelf}}
      <DNavigationItem
        @route="userPrivateMessages.user.new"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-new"
      >
        {{dIcon "circle-exclamation"}}
        <span>{{@controller.newLinkText}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="userPrivateMessages.user.unread"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-unread"
      >
        {{dIcon "circle-plus"}}
        <span>{{@controller.unreadLinkText}}</span>
      </DNavigationItem>
    {{/if}}

    <DNavigationItem
      @route="userPrivateMessages.user.archive"
      @ariaCurrentContext="subNav"
      class="user-nav__messages-archive"
    >
      {{dIcon "box-archive"}}
      <span>{{i18n "user.messages.archive"}}</span>
    </DNavigationItem>

  </MessagesSecondaryNav>

  {{outlet}}
</template>
