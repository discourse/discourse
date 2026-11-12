import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import CreateButton from "discourse/components/mobile-tab-bar/create-button";
import MenuButton from "discourse/components/mobile-tab-bar/menu-button";
import MoreTab from "discourse/components/mobile-tab-bar/more-tab";
import Tab from "discourse/components/mobile-tab-bar/tab";
import htmlClass from "discourse/helpers/html-class";
import { SCROLLED_DOWN } from "discourse/services/scroll-direction";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class MobileTabBar extends Component {
  @service composer;
  @service mobileTabBar;
  @service scrollDirection;

  #track = null;
  #controlsObserver = null;

  get isVisible() {
    return this.mobileTabBar.enabled && !this.composer.isOpen;
  }

  // Out of the way while reading down a page, back on the way up. A page
  // too short to scroll never counts as scrolled down, so it keeps them.
  get viewsTucked() {
    return this.scrollDirection.lastScrollDirection === SCROLLED_DOWN;
  }

  @action
  registerViewsSlot(element) {
    this.mobileTabBar.viewsSlot = element;
    this.#controlsObserver = new ResizeObserver(() =>
      this.#placeTabHighlight()
    );
    this.#controlsObserver.observe(element.nextElementSibling);
  }

  @action
  unregisterViewsSlot() {
    this.#controlsObserver?.disconnect();
    this.#controlsObserver = null;
    this.mobileTabBar.viewsSlot = null;
  }

  @action
  followActiveTab(track) {
    this.#track = track;
    this.#placeTabHighlight();
  }

  // Moves the highlight under the current section's tab: instantly the first
  // time, so it doesn't slide in from the edge, then sliding
  #placeTabHighlight() {
    const track = this.#track;
    const tab = track?.querySelector(".mobile-tab-bar__tab.--active");

    if (!tab) {
      return;
    }

    track.style.setProperty(
      "--mobile-tab-bar-highlight-x",
      `${tab.offsetLeft}px`
    );
    track.style.setProperty(
      "--mobile-tab-bar-highlight-width",
      `${tab.offsetWidth}px`
    );

    if (!("sliding" in track.dataset)) {
      requestAnimationFrame(() => (track.dataset.sliding = ""));
    }
  }

  <template>
    {{#if this.isVisible}}
      {{htmlClass "footer-nav-visible" "mobile-tab-bar-visible"}}
      {{#if this.mobileTabBar.isNestedPage}}
        {{htmlClass "mobile-tab-bar-nested"}}
      {{/if}}
      {{#if this.mobileTabBar.isTitledPage}}
        {{htmlClass "mobile-tab-bar-titled"}}
      {{/if}}

      <nav
        aria-label={{i18n "mobile_tab_bar.label"}}
        class={{dConcatClass
          "mobile-tab-bar"
          (if this.viewsTucked "--views-tucked")
          (unless this.mobileTabBar.sectionTabKey "--no-section")
        }}
      >
        <div
          class="mobile-tab-bar__views"
          {{didInsert this.registerViewsSlot}}
          {{willDestroy this.unregisterViewsSlot}}
        ></div>
        <div class="mobile-tab-bar__controls">
          <MenuButton />
          <div class="mobile-tab-bar__tabs">
            <div
              class="mobile-tab-bar__track"
              {{didInsert this.followActiveTab}}
              {{didUpdate
                this.followActiveTab
                this.mobileTabBar.sectionTabKey
                this.mobileTabBar.barTabs
              }}
            >
              <span aria-hidden="true" class="mobile-tab-bar__highlight"></span>
              {{#each this.mobileTabBar.barTabs key="key" as |tab|}}
                <Tab @tab={{tab}} />
              {{/each}}
              {{#if this.mobileTabBar.moreTabs.length}}
                <MoreTab />
              {{/if}}
            </div>
          </div>
          <CreateButton @canSignUp={{@canSignUp}} />
        </div>
      </nav>
    {{/if}}
  </template>
}
