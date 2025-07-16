import Component from "@ember/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { ajax } from "discourse/lib/ajax";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import formatCurrency from "../helpers/format-currency";

const SIDEBAR_BODY_CLASS = "subscription-campaign-sidebar";

@classNameBindings("isGoalMet:goal-met")
export default class CampaignBanner extends Component {
  @service router;

  dismissed = false;
  loading = false;

  @setting("discourse_subscriptions_campaign_banner_shadow_color")
  dropShadowColor;

  @setting("discourse_subscriptions_campaign_banner_bg_image")
  backgroundImageUrl;

  @equal(
    "siteSettings.discourse_subscriptions_campaign_banner_location",
    "Sidebar"
  )
  isSidebar;

  @setting("discourse_subscriptions_campaign_subscribers") subscribers;

  @equal("siteSettings.discourse_subscriptions_campaign_type", "Subscribers")
  subscriberGoal;

  @setting("discourse_subscriptions_currency") currency;

  @setting("discourse_subscriptions_campaign_amount_raised") amountRaised;

  @setting("discourse_subscriptions_campaign_goal") goalTarget;

  @setting("discourse_subscriptions_campaign_product") product;

  @setting("discourse_subscriptions_pricing_table_enabled") pricingTableEnabled;

  @setting("discourse_subscriptions_campaign_show_contributors")
  showContributors;

  init() {
    super.init(...arguments);

    this.set("contributors", []);

    // add background-image url to stylesheet
    if (this.backgroundImageUrl) {
      const backgroundUrl = `url(${this.backgroundImageUrl}`.replace(/\\/g, "");
      if (
        document.documentElement.style.getPropertyValue(
          "--campaign-background-image"
        ) !== backgroundUrl
      ) {
        document.documentElement.style.setProperty(
          "--campaign-background-image",
          backgroundUrl
        );
      }
    }

    if (this.currentUser && this.showContributors) {
      return ajax("/s/contributors", { method: "get" }).then((result) => {
        this.setProperties({
          contributors: result,
          loading: false,
        });
      });
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    if (this.isSidebar && this.shouldShow && !this.site.mobileView) {
      document.body.classList.add(SIDEBAR_BODY_CLASS);
    } else {
      document.body.classList.remove(SIDEBAR_BODY_CLASS);
    }

    // makes sure to only play animation once, & not repeat on reload
    if (this.isGoalMet) {
      const successAnimationKey = this.keyValueStore.get(
        "campaign_success_animation"
      );

      if (!successAnimationKey) {
        later(() => {
          this.keyValueStore.set({
            key: "campaign_success_animation",
            value: Date.now(),
          });
          document.body.classList.add("success-animation-off");
        }, 7000);
      } else {
        document.body.classList.add("success-animation-off");
      }
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    document.body.classList.remove(SIDEBAR_BODY_CLASS);
  }

  @discourseComputed("backgroundImageUrl")
  bannerInfoStyle(backgroundImageUrl) {
    if (!backgroundImageUrl) {
      return "";
    }

    return `background-image: linear-gradient(
        0deg,
        rgba(var(--secondary-rgb), 0.75) 0%,
        rgba(var(--secondary-rgb), 0.75) 100%),
        var(--campaign-background-image);
      background-size: cover;
      background-repeat: no-repeat;`;
  }

  @discourseComputed(
    "router.currentRouteName",
    "currentUser",
    "siteSettings.discourse_subscriptions_campaign_enabled",
    "visible"
  )
  shouldShow(currentRoute, currentUser, enabled, visible) {
    // do not show on admin or subscriptions pages
    const showOnRoute =
      currentRoute !== "discovery.s" &&
      !currentRoute.split(".")[0].includes("admin") &&
      currentRoute.split(".")[0] !== "subscribe" &&
      currentRoute.split(".")[0] !== "subscriptions";

    if (!this.site.show_campaign_banner) {
      return false;
    }

    // make sure not to render above main container when inside a topic
    if (
      this.connectorName === "above-main-container" &&
      currentRoute.includes("topic")
    ) {
      return false;
    }

    return showOnRoute && currentUser && enabled && visible;
  }

  @observes("dismissed")
  _updateBodyClasses() {
    if (this.dismissed) {
      document.body.classList.remove(SIDEBAR_BODY_CLASS);
    }
  }

  @discourseComputed("dismissed")
  visible(dismissed) {
    const dismissedBannerKey = this.keyValueStore.get(
      "dismissed_campaign_banner"
    );
    const threeMonths = 2628000000 * 3;

    const bannerDismissedTime = new Date(dismissedBannerKey);
    const now = Date.now();

    return (
      (!dismissedBannerKey || now - bannerDismissedTime > threeMonths) &&
      !dismissed
    );
  }

  @discourseComputed
  subscribeRoute() {
    if (this.pricingTableEnabled) {
      return "subscriptions";
    }
    return "subscribe";
  }

  @discourseComputed
  isGoalMet() {
    const currentVolume = this.subscriberGoal
      ? this.subscribers
      : this.amountRaised;
    return currentVolume >= this.goalTarget;
  }

  @action
  dismissBanner() {
    this.set("dismissed", true);
    this.keyValueStore.set({
      key: "dismissed_campaign_banner",
      value: Date.now(),
    });
  }

  <template>
    {{#if this.shouldShow}}
      <div
        class="campaign-banner"
        style={{htmlSafe (concat "box-shadow: 5px 5px #" this.dropShadowColor)}}
      >
        <DButton @icon="xmark" @action={{this.dismissBanner}} class="close" />

        <div
          class="campaign-banner-info"
          style={{htmlSafe this.bannerInfoStyle}}
        >
          {{#if this.isGoalMet}}
            <h2 class="campaign-banner-info-header">
              {{i18n "discourse_subscriptions.campaign.success_title"}}
            </h2>

            <p class="campaign-banner-info-description">
              {{i18n "discourse_subscriptions.campaign.success_body"}}
            </p>
          {{else}}
            <h2 class="campaign-banner-info-header">
              {{i18n "discourse_subscriptions.campaign.title"}}
            </h2>

            <p class="campaign-banner-info-description">
              {{i18n "discourse_subscriptions.campaign.body"}}
            </p>

            {{#if this.product}}
              <LinkTo
                @route="subscribe.show"
                @model={{this.product}}
                @disabled={{this.product.subscribed}}
                class="btn btn-primary campaign-banner-info-button"
              >
                {{icon "far-heart"}}
                {{icon "heart" class="hover-heart"}}
                {{i18n "discourse_subscriptions.campaign.button"}}
              </LinkTo>
            {{else}}
              <LinkTo
                @route={{this.subscribeRoute}}
                class="btn btn-primary campaign-banner-info-button"
              >
                {{icon "far-heart"}}
                {{icon "heart" class="hover-heart"}}
                {{i18n "discourse_subscriptions.campaign.button"}}
              </LinkTo>
            {{/if}}
          {{/if}}
        </div>

        <div class="campaign-banner-progress">
          {{#if this.isGoalMet}}
            <div class="fireworks">
              <div class="before"></div>
              <div class="after"></div>
            </div>

            <div class="campaign-banner-progress-success"></div>

            {{#if this.subscriberGoal}}
              <p class="campaign-banner-progress-description">
                {{htmlSafe
                  (i18n
                    "discourse_subscriptions.campaign.goal_comparison"
                    current=this.subscribers
                    goal=this.goalTarget
                  )
                }}
                {{i18n "discourse_subscriptions.campaign.subscribers"}}
              </p>
            {{else}}
              <p class="campaign-banner-progress-description">
                {{htmlSafe
                  (i18n
                    "discourse_subscriptions.campaign.goal_comparison"
                    current=(formatCurrency this.currency this.amountRaised)
                    goal=(formatCurrency this.currency this.goalTarget)
                  )
                }}
                {{i18n "discourse_subscriptions.campaign.raised"}}
              </p>

              {{#if this.showContributors}}
                <ConditionalLoadingSpinner
                  @condition={{this.loading}}
                  @size="small"
                >
                  <div class="campaign-banner-progress-users">
                    <p class="campaign-banner-progress-users-title">
                      <strong>
                        {{i18n
                          "discourse_subscriptions.campaign.recent_contributors"
                        }}
                      </strong>
                    </p>

                    <div class="campaign-banner-progress-users-avatars">
                      {{#each this.contributors as |contributor|}}
                        {{avatar
                          contributor
                          avatarTemplatePath="avatar_template"
                          usernamePath="username"
                          namePath="name"
                          imageSize="small"
                        }}
                      {{/each}}
                    </div>
                  </div>
                </ConditionalLoadingSpinner>
              {{/if}}
            {{/if}}
          {{else}}
            {{#if this.subscriberGoal}}
              <progress
                class="campaign-banner-progress-bar"
                value={{this.subscribers}}
                max={{this.siteSettings.discourse_subscriptions_campaign_goal}}
              ></progress>

              <p class="campaign-banner-progress-description">
                {{htmlSafe
                  (i18n
                    "discourse_subscriptions.campaign.goal_comparison"
                    current=this.subscribers
                    goal=this.goalTarget
                  )
                }}
                {{i18n "discourse_subscriptions.campaign.subscribers"}}
              </p>
            {{else}}
              <progress
                class="campaign-banner-progress-bar"
                value={{this.amountRaised}}
                max={{this.siteSettings.discourse_subscriptions_campaign_goal}}
              ></progress>

              <p class="campaign-banner-progress-description">
                {{htmlSafe
                  (i18n
                    "discourse_subscriptions.campaign.goal_comparison"
                    current=(formatCurrency this.currency this.amountRaised)
                    goal=(formatCurrency this.currency this.goalTarget)
                  )
                }}
                {{i18n "discourse_subscriptions.campaign.raised"}}
              </p>
            {{/if}}

            {{#if this.showContributors}}
              <ConditionalLoadingSpinner
                @condition={{this.loading}}
                @size="small"
              >
                <div class="campaign-banner-progress-users">
                  <p class="campaign-banner-progress-users-title">
                    <strong>
                      {{i18n
                        "discourse_subscriptions.campaign.recent_contributors"
                      }}
                    </strong>
                  </p>

                  <div class="campaign-banner-progress-users-avatars">
                    {{#each this.contributors as |contributor|}}
                      {{avatar
                        contributor
                        avatarTemplatePath="avatar_template"
                        usernamePath="username"
                        namePath="name"
                        imageSize="small"
                      }}
                    {{/each}}
                  </div>
                </div>
              </ConditionalLoadingSpinner>
            {{/if}}
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
