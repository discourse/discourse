import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DialogHolder from "dialog-holder/components/dialog-holder";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import CardContainer from "discourse/components/card-container";
import ComposerContainer from "discourse/components/composer-container";
import CustomHtml from "discourse/components/custom-html";
import DDocument from "discourse/components/d-document";
import DStyles from "discourse/components/d-styles";
import DVirtualHeight from "discourse/components/d-virtual-height";
import DiscourseRoot from "discourse/components/discourse-root";
import FooterNav from "discourse/components/footer-nav";
import GlimmerSiteHeader from "discourse/components/glimmer-site-header";
import GlobalNotice from "discourse/components/global-notice";
import LoadingSliderFallbackSpinner from "discourse/components/loading-slider-fallback-spinner";
import ModalContainer from "discourse/components/modal-container";
import NotificationConsentBanner from "discourse/components/notification-consent-banner";
import OfflineIndicator from "discourse/components/offline-indicator";
import PageLoadingSlider from "discourse/components/page-loading-slider";
import PluginOutlet from "discourse/components/plugin-outlet";
import PoweredByDiscourse from "discourse/components/powered-by-discourse";
import PwaInstallBanner from "discourse/components/pwa-install-banner";
import RenderGlimmerContainer from "discourse/components/render-glimmer-container";
import Sidebar from "discourse/components/sidebar";
import SoftwareUpdatePrompt from "discourse/components/software-update-prompt";
import TopicEntrance from "discourse/components/topic-entrance";
import WelcomeBanner from "discourse/components/welcome-banner";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import DMenus from "float-kit/components/d-menus";
import DToasts from "float-kit/components/d-toasts";
import DTooltips from "float-kit/components/d-tooltips";

export default RouteTemplate(
  <template>
    <DStyles />
    <DVirtualHeight />

    <DiscourseRoot {{didInsert @controller.trackDiscoursePainted}}>
      {{#if @controller.showSkipToContent}}
        <a href="#main-container" id="skip-link">{{i18n
            "skip_to_main_content"
          }}</a>
      {{/if}}
      <DDocument />
      <PageLoadingSlider />
      <PluginOutlet
        @name="above-site-header"
        @connectorTagName="div"
        @outletArgs={{lazyHash
          currentPath=@controller.router._router.currentPath
        }}
      />

      {{#if @controller.showSiteHeader}}
        <GlimmerSiteHeader
          @canSignUp={{@controller.canSignUp}}
          @showCreateAccount={{routeAction "showCreateAccount"}}
          @showLogin={{routeAction "showLogin"}}
          @showKeyboard={{routeAction "showKeyboardShortcutsHelp"}}
          @toggleMobileView={{routeAction "toggleMobileView"}}
          @logout={{routeAction "logout"}}
          @sidebarEnabled={{@controller.sidebarEnabled}}
          @showSidebar={{@controller.showSidebar}}
          @toggleSidebar={{@controller.toggleSidebar}}
        />
      {{/if}}

      <SoftwareUpdatePrompt />

      {{#if @controller.siteSettings.enable_offline_indicator}}
        <OfflineIndicator />
      {{/if}}

      <PluginOutlet
        @name="below-site-header"
        @connectorTagName="div"
        @outletArgs={{lazyHash
          currentPath=@controller.router._router.currentPath
        }}
      />

      <div id="main-outlet-wrapper" class="wrap" role="main">
        <div class="sidebar-wrapper">
          {{! empty div allows for animation }}
          {{#if (and @controller.sidebarEnabled @controller.showSidebar)}}
            <Sidebar @toggleSidebar={{@controller.toggleSidebar}} />
          {{/if}}
        </div>

        <LoadingSliderFallbackSpinner />

        <PluginOutlet @name="before-main-outlet" />

        <div id="main-outlet">
          <PluginOutlet @name="above-main-container" @connectorTagName="div" />

          <WelcomeBanner />

          <div class="container" id="main-container">
            {{#if @controller.showTop}}
              <CustomHtml @name="top" />
            {{/if}}
            <NotificationConsentBanner />
            <PwaInstallBanner />
            <GlobalNotice />
            <PluginOutlet
              @name="top-notices"
              @connectorTagName="div"
              @outletArgs={{lazyHash
                currentPath=@controller.router._router.currentPath
              }}
            />
          </div>

          {{outlet}}

          <CardContainer />
          <PluginOutlet
            @name="main-outlet-bottom"
            @outletArgs={{lazyHash showFooter=@controller.showFooter}}
          />
        </div>

        <PluginOutlet @name="after-main-outlet" />

        {{#if @controller.showPoweredBy}}
          <PoweredByDiscourse />
        {{/if}}
      </div>

      <PluginOutlet
        @name="above-footer"
        @connectorTagName="div"
        @outletArgs={{lazyHash showFooter=@controller.showFooter}}
      />
      {{#if @controller.showFooter}}
        <CustomHtml
          @name="footer"
          @triggerAppEvent="true"
          @classNames="custom-footer-content"
        />
      {{/if}}
      <PluginOutlet
        @name="below-footer"
        @connectorTagName="div"
        @outletArgs={{lazyHash showFooter=@controller.showFooter}}
      />

      <ModalContainer />
      <DialogHolder />
      <TopicEntrance />
      <ComposerContainer />
      <RenderGlimmerContainer />

      {{#if @controller.showFooterNav}}
        <PluginOutlet @name="footer-nav">
          <FooterNav />
        </PluginOutlet>
      {{/if}}
    </DiscourseRoot>

    <DMenus />
    <DTooltips />
    <DToasts />
  </template>
);
