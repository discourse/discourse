import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import htmlClass from "discourse/helpers/html-class";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { SCROLLED_UP, UNSCROLLED } from "discourse/services/scroll-direction";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class FooterNav extends Component {
  @service capabilities;
  @service scrollDirection;
  @service composer;
  @service modal;
  @service historyStore;
  @service router;

  EXCLUDE_IN_ROUTES = [
    "activate-account",
    "invites.show",
    "login",
    "password-reset",
    "signup",
  ];

  get isVisible() {
    const { currentRouteName } = this.router;

    return (
      [UNSCROLLED, SCROLLED_UP].includes(
        this.scrollDirection.lastScrollDirection
      ) &&
      !this.composer.isOpen &&
      (this.capabilities.isAppWebview || this.canGoBack || this.canGoForward) &&
      !this.EXCLUDE_IN_ROUTES.includes(currentRouteName)
    );
  }

  get canGoBack() {
    return this.historyStore.hasPastEntries || !!document.referrer;
  }

  get canGoForward() {
    return this.historyStore.hasFutureEntries;
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
  goBack(_, event) {
    window.history.back();
    event.preventDefault();
  }

  @action
  goForward(_, event) {
    window.history.forward();
    event.preventDefault();
  }

  _modalOn() {
    postRNWebviewMessage("headerBg", "rgb(0, 0, 0)");
  }

  _modalOff() {
    const header = document.querySelector(".d-header-wrap .d-header");
    if (header) {
      postRNWebviewMessage(
        "headerBg",
        window.getComputedStyle(header).backgroundColor
      );
    }
  }

  <template>
    {{this.setDiscourseHubHeaderBg this.modal.activeModal}}

    {{#if this.capabilities.isIpadOS}}
      {{htmlClass "footer-nav-ipad"}}
    {{else if this.isVisible}}
      {{htmlClass "footer-nav-visible"}}
    {{/if}}

    <div class={{dConcatClass "footer-nav" (if this.isVisible "visible")}}>
      <div class="footer-nav-widget">
        <DButton
          class="btn-flat btn-large"
          @action={{this.goBack}}
          @disabled={{not this.canGoBack}}
          @forwardEvent={{true}}
          @icon="chevron-left"
          @title="footer_nav.back"
        />

        <DButton
          class="btn-flat btn-large"
          @action={{this.goForward}}
          @disabled={{not this.canGoForward}}
          @forwardEvent={{true}}
          @icon="chevron-right"
          @title="footer_nav.forward"
        />

        {{#if this.capabilities.isAppWebview}}
          <DButton
            class="btn-flat btn-large"
            @action={{this.share}}
            @icon="link"
            @title="footer_nav.share"
          />

          <DButton
            class="btn-flat btn-large"
            @action={{this.dismiss}}
            @icon="chevron-down"
            @title="footer_nav.dismiss"
          />
        {{/if}}
      </div>
    </div>
  </template>
}
