import bodyClass from "discourse/helpers/body-class";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";

export default <template>
  {{#if @controller.can_see_invite_details}}
    {{bodyClass "user-invites-page"}}

    <div class="user-navigation user-navigation-secondary">
      <DHorizontalOverflowNav @ariaLabel="User secondary - invites">
        <DNavItem
          @route="userInvited.show"
          @routeParam="pending"
          @i18nLabel={{@controller.pendingLabel}}
        />
        <DNavItem
          @route="userInvited.show"
          @routeParam="expired"
          @i18nLabel={{@controller.expiredLabel}}
        />
        <DNavItem
          @route="userInvited.show"
          @routeParam="redeemed"
          @i18nLabel={{@controller.redeemedLabel}}
        />
      </DHorizontalOverflowNav>
    </div>
  {{/if}}

  {{outlet}}
</template>
