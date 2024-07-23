import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import htmlClass from "discourse/helpers/html-class";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { SCROLLED_UP, UNSCROLLED } from "discourse/services/scroll-direction";
import not from "truth-helpers/helpers/not";

class FooterNav extends Component {
  @service appEvents;
  @service capabilities;
  @service scrollDirection;
  @service composer;
  @service modal;

  @tracked currentRouteIndex = 0;

  routeHistory = new TrackedArray();
  backForwardClicked = false;

  registerAppEvents = modifierFn(() => {
    this.appEvents.on("page:changed", this, "_routeChanged");

    return () => {
      this.appEvents.off("page:changed", this, "_routeChanged");
    };
  });

  @action
  _routeChanged(route) {
    // only update route history if not using back/forward nav
    if (this.backForwardClicked) {
      this.backForwardClicked = null;
      return;
    }

    // we only keep last 100 routes in history
    if (this.routeHistory.length >= 100) {
      this.routeHistory.shift();
    }

    this.routeHistory.push(route.url);
    this.currentRouteIndex = this.routeHistory.length;
  }

  _modalOn() {
    const backdrop = document.querySelector(".modal-backdrop");
    if (!backdrop) {
      return;
    }

    postRNWebviewMessage(
      "headerBg",
      getComputedStyle(backdrop)["background-color"]
    );
  }

  _modalOff() {
    const dheader = document.querySelector(".d-header");
    if (!dheader) {
      return;
    }

    postRNWebviewMessage(
      "headerBg",
      document.documentElement.style.getPropertyValue("--header_background")
    );
  }

  @action
  setDiscourseHubHeaderBg(hasAnActiveModal) {
    if (!this.capabilities.isAppWebview) {
      return;
    }

    if (hasAnActiveModal) {
      this._modalOn();
    } else {
      this._modalOff();
    }
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
    this.backForwardClicked = true;
    window.history.back();
  }

  @action
  goForward() {
    this.currentRouteIndex = this.currentRouteIndex + 1;
    this.backForwardClicked = true;
    window.history.forward();
  }

  get isVisible() {
    return (
      [UNSCROLLED, SCROLLED_UP].includes(
        this.scrollDirection.lastScrollDirection
      ) && !this.composer.isOpen
    );
  }

  get canGoBack() {
    return this.currentRouteIndex > 1 || !!document.referrer;
  }

  get canGoForward() {
    return this.currentRouteIndex < this.routeHistory.length;
  }

  <template>
    {{this.setDiscourseHubHeaderBg this.modal.activeModal}}

    {{#if this.capabilities.isIpadOS}}
      {{htmlClass "footer-nav-ipad"}}
    {{else if this.isVisible}}
      {{htmlClass "footer-nav-visible"}}
    {{/if}}

    <div
      class={{concatClass "footer-nav" (if this.isVisible "visible")}}
      {{this.registerAppEvents}}
    >
      <div class="footer-nav-widget">
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
    </div>
  </template>
}

export default FooterNav;
