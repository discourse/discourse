import bodyClass from "discourse/helpers/body-class";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";

export default <template>
  {{#if @controller.can_see_invite_details}}
    {{bodyClass "user-invites-page"}}

    <div class="user-navigation user-navigation-secondary">
      <DHorizontalOverflowNav @ariaLabel="User secondary - invites">
        <DNavItem
          @i18nLabel={{@controller.pendingLabel}}
          @route="userInvited.show"
          @routeParam="pending"
        />
        <DNavItem
          @i18nLabel={{@controller.expiredLabel}}
          @route="userInvited.show"
          @routeParam="expired"
        />
        <DNavItem
          @i18nLabel={{@controller.redeemedLabel}}
          @route="userInvited.show"
          @routeParam="redeemed"
        />
      </DHorizontalOverflowNav>
    </div>
  {{/if}}

  {{outlet}}
</template>
