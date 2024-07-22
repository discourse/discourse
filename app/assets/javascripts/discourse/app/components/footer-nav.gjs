import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { mixin } from "@ember/object/mixin";
import { cancel, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import documentClass from "discourse/helpers/document-class";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import MobileScrollDirection from "discourse/mixins/mobile-scroll-direction";
import Scrolling from "discourse/mixins/scrolling";
import not from "truth-helpers/helpers/not";

const MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE = 150;

class FooterNav extends Component {
  @service appEvents;
  @service capabilities;

  @tracked canGoBack = false;
  @tracked canGoForward = false;
  @tracked mobileScrollDirection = "down";

  currentRouteIndex = 0;
  routeHistory = [];
  backForwardClicked = false;
  scrollEventDisabled = false;

  registerScrollhandler = modifierFn(() => {
    window.addEventListener("resize", this.scrolled);
    this.bindScrolling();

    return () => {
      cancel(this._throttleHandler);
      window.removeEventListener("resize", this.scrolled);
      this.unbindScrolling();
    };
  });

  registerAppEvents = modifierFn(() => {
    this.appEvents.on("page:changed", this, "_routeChanged");
    if (this.capabilities.isAppWebview) {
      this.appEvents.on("modal:body-shown", this, "_modalOn");
      this.appEvents.on("modal:body-dismissed", this, "_modalOff");
    }
    this.appEvents.on("composer:opened", this, "_composerOpened");
    this.appEvents.on("composer:closed", this, "_composerClosed");

    return () => {
      this.appEvents.off("page:changed", this, "_routeChanged");
      if (this.capabilities.isAppWebview) {
        this.appEvents.off("modal:body-shown", this, "_modalOn");
        this.appEvents.off("modal:body-removed", this, "_modalOff");
      }
      this.appEvents.off("composer:opened", this, "_composerOpened");
      this.appEvents.off("composer:closed", this, "_composerClosed");
    };
  });

  @action
  _routeChanged(route) {
    // only update route history if not using back/forward nav
    if (this.backForwardClicked) {
      this.backForwardClicked = null;
      return;
    }

    this.routeHistory.push(route.url);
    this.currentRouteIndex = this.routeHistory.length;
    this.setBackForward();
  }

  @action
  _composerOpened() {
    this.mobileScrollDirection = "down";
    this.scrollEventDisabled = true;
  }

  @action
  _composerClosed() {
    this.mobileScrollDirection = null;
    this.scrollEventDisabled = false;
  }

  @action
  _modalOn() {
    const backdrop = document.querySelector(".modal-backdrop");
    if (backdrop) {
      postRNWebviewMessage(
        "headerBg",
        getComputedStyle(backdrop)["background-color"]
      );
    }
  }

  @action
  _modalOff() {
    const dheader = document.querySelector(".d-header");
    if (!dheader) {
      return;
    }

    postRNWebviewMessage(
      "headerBg",
      getComputedStyle(dheader)["background-color"]
    );
  }

  @action
  dismiss() {
    postRNWebviewMessage("dismiss", true);
  }

  @action
  share() {
    postRNWebviewMessage("shareUrl", window.location.href);
  }

  @action
  goBack() {
    this.currentRouteIndex = this.currentRouteIndex - 1;
    this.setBackForward();
    this.backForwardClicked = true;
    window.history.back();
  }

  @action
  goForward() {
    this.currentRouteIndex = this.currentRouteIndex + 1;
    this.setBackForward();
    this.backForwardClicked = true;
    window.history.forward();
  }

  // The user has scrolled the window, or it is finished rendering and ready for processing.
  @action
  scrolled() {
    if (this.scrollEventDisabled) {
      return;
    }

    this._throttleHandler = throttle(
      this,
      this.calculateDirection,
      window.pageYOffset,
      MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE
    );
  }

  setBackForward() {
    this.canGoBack =
      this.currentRouteIndex > 1 || document.referrer ? true : false;
    this.canGoForward =
      this.currentRouteIndex < this.routeHistory.length ? true : false;
  }

  <template>
    {{#if this.capabilities.isIpadOS}}
      {{documentClass "footer-nav-ipad"}}
    {{else}}
      {{#unless this.mobileScrollDirection}}
        {{documentClass "footer-nav-visible"}}
      {{/unless}}
    {{/if}}

    <div
      class={{concatClass
        "footer-nav-widget"
        "footer-nav"
        (unless this.mobileScrollDirection "visible")
      }}
      {{this.registerScrollhandler}}
      {{this.registerAppEvents}}
    >
      <DButton
        @action={{this.goBack}}
        @icon="chevron-left"
        class="btn-flat btn-large"
        @disabled={{not this.canGoBack}}
        @title="footer_nav.back"
      />

      <DButton
        @action={{this.goForward}}
        @icon="chevron-right"
        class="btn-flat btn-large"
        @disabled={{not this.canGoForward}}
        @title="footer_nav.forward"
      />

      {{#if this.capabilities.isAppWebview}}
        <DButton
          @action={{this.share}}
          @icon="link"
          class="btn-flat btn-large"
          @title="footer_nav.share"
        />

        <DButton
          @action={{this.dismiss}}
          @icon="chevron-down"
          class="btn-flat btn-large"
          @title="footer_nav.dismiss"
        />
      {{/if}}
    </div>
  </template>
}

mixin(FooterNav.prototype, MobileScrollDirection);
mixin(FooterNav.prototype, Scrolling);

export default FooterNav;
