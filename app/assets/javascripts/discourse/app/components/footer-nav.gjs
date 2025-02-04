import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import htmlClass from "discourse/helpers/html-class";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { SCROLLED_UP, UNSCROLLED } from "discourse/services/scroll-direction";
import not from "truth-helpers/helpers/not";

export default class FooterNav extends Component {
  @service appEvents;
  @service capabilities;
  @service scrollDirection;
  @service composer;
  @service modal;
  @service historyStore;

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

  get isVisible() {
    return (
      [UNSCROLLED, SCROLLED_UP].includes(
        this.scrollDirection.lastScrollDirection
      ) &&
      !this.composer.isOpen &&
      (this.capabilities.isAppWebview || this.canGoBack || this.canGoForward)
    );
  }

  get canGoBack() {
    return this.historyStore.hasPastEntries || !!document.referrer;
  }

  get canGoForward() {
    return this.historyStore.hasFutureEntries;
  }

  <template>
    {{this.setDiscourseHubHeaderBg this.modal.activeModal}}

    {{#if this.capabilities.isIpadOS}}
      {{htmlClass "footer-nav-ipad"}}
    {{else if this.isVisible}}
      {{htmlClass "footer-nav-visible"}}
    {{/if}}

    <div class={{concatClass "footer-nav" (if this.isVisible "visible")}}>
      <div class="footer-nav-widget">
        <DButton
          @action={{this.goBack}}
          @icon="chevron-left"
          class="btn-flat btn-large"
          @disabled={{not this.canGoBack}}
          @title="footer_nav.back"
          @forwardEvent={{true}}
        />

        <DButton
          @action={{this.goForward}}
          @icon="chevron-right"
          class="btn-flat btn-large"
          @disabled={{not this.canGoForward}}
          @title="footer_nav.forward"
          @forwardEvent={{true}}
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
