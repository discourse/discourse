import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import MobileNav from "discourse/components/mobile-nav";
import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "user-billing-page"}}

    <section class="user-secondary-navigation">
      <MobileNav
        @desktopClass="action-list nav-stacked"
        @currentPath={{@controller.router._router.currentPath}}
        class="activity-nav"
      >
        <li>
          <LinkTo @route="user.billing.subscriptions">
            {{i18n "discourse_subscriptions.navigation.subscriptions"}}
          </LinkTo>
        </li>

        <li>
          <LinkTo @route="user.billing.payments">
            {{i18n "discourse_subscriptions.navigation.payments"}}
          </LinkTo>
        </li>
      </MobileNav>
    </section>

    <section class="user-content">
      {{outlet}}
    </section>
  </template>
);
