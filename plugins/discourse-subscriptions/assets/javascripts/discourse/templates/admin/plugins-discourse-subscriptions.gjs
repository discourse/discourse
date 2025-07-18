import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <h2>{{i18n
        "discourse_subscriptions.title"
        site_name=@controller.siteSettings.title
      }}</h2>

    {{#if @controller.stripeConfigured}}
      <div class="discourse-subscriptions-buttons">
        {{#if @controller.campaignEnabled}}
          <DButton
            @label="discourse_subscriptions.campaign.refresh_campaign"
            @icon="rotate"
            @action={{@controller.triggerManualRefresh}}
          />
        {{else}}
          {{#unless @controller.campaignProductSet}}
            <DButton
              @label="discourse_subscriptions.campaign.one_click_campaign"
              @icon="square-plus"
              @action={{@controller.createOneClickCampaign}}
              @isLoading={{@controller.loading}}
            />
          {{/unless}}
        {{/if}}
      </div>

      <ul class="nav nav-pills">
        <NavItem
          @route="adminPlugins.discourse-subscriptions.products"
          @label="discourse_subscriptions.admin.products.title"
        />
        <NavItem
          @route="adminPlugins.discourse-subscriptions.coupons"
          @label="discourse_subscriptions.admin.coupons.title"
        />
        <NavItem
          @route="adminPlugins.discourse-subscriptions.subscriptions"
          @label="discourse_subscriptions.admin.subscriptions.title"
        />
      </ul>

      <hr />

      <div id="discourse-subscriptions-admin">
        {{outlet}}
      </div>
    {{else}}
      <p>{{i18n "discourse_subscriptions.admin.unconfigured"}}</p>
      <p>
        <a href="https://meta.discourse.org/t/discourse-subscriptions/140818/">
          {{i18n "discourse_subscriptions.admin.on_meta"}}
        </a>
      </p>
    {{/if}}
  </template>
);
