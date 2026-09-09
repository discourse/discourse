import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <MessagesSecondaryNav>

    <DNavigationItem
      class="user-nav__messages-group-latest"
      @ariaCurrentContext="subNav"
      @route="userPrivateMessages.group.index"
    >
      {{dIcon "envelope"}}
      <span>{{i18n "categories.latest"}}</span>
    </DNavigationItem>

    {{#if @controller.viewingSelf}}
      <DNavigationItem
        class="user-nav__messages-group-new"
        @ariaCurrentContext="subNav"
        @route="userPrivateMessages.group.new"
      >
        {{dIcon "circle-exclamation"}}
        <span>{{@controller.newLinkText}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__messages-group-unread"
        @ariaCurrentContext="subNav"
        @route="userPrivateMessages.group.unread"
      >
        {{dIcon "circle-plus"}}
        <span>{{@controller.unreadLinkText}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__messages-group-archive"
        @ariaCurrentContext="subNav"
        @route="userPrivateMessages.group.archive"
      >
        {{dIcon "box-archive"}}
        <span>{{i18n "user.messages.archive"}}</span>
      </DNavigationItem>
    {{/if}}
  </MessagesSecondaryNav>

  <div class="group-messages group-{{@controller.group.name}}">
    {{outlet}}
  </div>
</template>
