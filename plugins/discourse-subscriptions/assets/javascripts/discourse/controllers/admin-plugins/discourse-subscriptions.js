import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class AdminPluginsDiscourseSubscriptionsController extends Controller {
  @service dialog;

  loading = false;

  @discourseComputed
  stripeConfigured() {
    return !!this.siteSettings.discourse_subscriptions_public_key;
  }

  @discourseComputed
  campaignEnabled() {
    return this.siteSettings.discourse_subscriptions_campaign_enabled;
  }

  @discourseComputed
  campaignProductSet() {
    return !!this.siteSettings.discourse_subscriptions_campaign_product;
  }

  @action
  triggerManualRefresh() {
    ajax(`/s/admin/refresh`, {
      method: "post",
    }).then(() => {
      this.dialog.alert(i18n("discourse_subscriptions.campaign.refresh_page"));
    });
  }

  @action
  createOneClickCampaign() {
    this.dialog.yesNoConfirm({
      title: i18n("discourse_subscriptions.campaign.confirm_creation_title"),
      message: htmlSafe(
        i18n("discourse_subscriptions.campaign.confirm_creation")
      ),
      didConfirm: () => {
        this.set("loading", true);

        ajax(`/s/admin/create-campaign`, {
          method: "post",
        })
          .then(() => {
            this.set("loading", false);
            this.dialog.confirm({
              message: i18n("discourse_subscriptions.campaign.created"),
              shouldDisplayCancel: false,
              didConfirm: () => this.send("showSettings"),
              didCancel: () => this.send("showSettings"),
            });
          })
          .catch(popupAjaxError);
      },
    });
  }
}
