import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class SubscriptionsAdminPluginActions extends Component {
  @service dialog;
  @service router;
  @service site;
  @service siteSettings;

  @tracked loading = false;

  get stripeConfigured() {
    return this.site.discourse_subscriptions_stripe_configured;
  }

  get campaignEnabled() {
    return this.siteSettings.discourse_subscriptions_campaign_enabled;
  }

  get campaignProductSet() {
    return !!this.siteSettings.discourse_subscriptions_campaign_product;
  }

  @action
  async triggerManualRefresh() {
    try {
      await ajax("/s/admin/refresh", { method: "post" });
      this.dialog.alert(i18n("discourse_subscriptions.campaign.refresh_page"));
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  createOneClickCampaign() {
    this.dialog.yesNoConfirm({
      title: i18n("discourse_subscriptions.campaign.confirm_creation_title"),
      message: trustHTML(
        i18n("discourse_subscriptions.campaign.confirm_creation")
      ),
      didConfirm: async () => {
        this.loading = true;

        try {
          await ajax("/s/admin/create-campaign", { method: "post" });

          this.dialog.confirm({
            message: i18n("discourse_subscriptions.campaign.created"),
            shouldDisplayCancel: false,
            didConfirm: () => this.showSettings(),
            didCancel: () => this.showSettings(),
          });
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.loading = false;
        }
      },
    });
  }

  showSettings() {
    this.router.transitionTo(
      "adminPlugins.show.settings",
      "discourse-subscriptions"
    );
  }

  <template>
    {{#if this.stripeConfigured}}
      {{#if this.campaignEnabled}}
        <@actions.Default
          @action={{this.triggerManualRefresh}}
          @icon="rotate"
          @label="discourse_subscriptions.campaign.refresh_campaign"
        />
      {{else if (not this.campaignProductSet)}}
        <@actions.Default
          @action={{this.createOneClickCampaign}}
          @icon="square-plus"
          @isLoading={{this.loading}}
          @label="discourse_subscriptions.campaign.one_click_campaign"
        />
      {{/if}}
    {{/if}}
  </template>
}
