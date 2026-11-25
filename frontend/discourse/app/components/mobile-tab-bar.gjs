import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import CreateButton from "discourse/components/mobile-tab-bar/create-button";
import MenuButton from "discourse/components/mobile-tab-bar/menu-button";
import MoreTab from "discourse/components/mobile-tab-bar/more-tab";
import Tab from "discourse/components/mobile-tab-bar/tab";
import htmlClass from "discourse/helpers/html-class";
import { routeWithin } from "discourse/lib/mobile-tab-bar";
import { SCROLLED_DOWN } from "discourse/services/scroll-direction";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import { i18n } from "discourse-i18n";

export default class MobileTabBar extends Component {
  @service capabilities;
  @service composer;
  @service mobileTabBar;
  @service router;
  @service scrollDirection;

  get isVisible() {
    return this.mobileTabBar.enabled && !this.composer.isOpen;
  }

  get tabsStyle() {
    const { barTabs, moreTabs } = this.mobileTabBar.tabLayout;
    const count = barTabs.length + (moreTabs.length ? 1 : 0);
    return trustHTML(`--mobile-tab-bar-tab-count: ${count};`);
  }

  get isTopic() {
    return routeWithin(this.router.currentRoute, "topic");
  }

  get #scrolledDown() {
    return this.scrollDirection.lastScrollDirection === SCROLLED_DOWN;
  }

  get viewsTucked() {
    return this.#scrolledDown && this.mobileTabBar.barTabs.length > 0;
  }

  get topicControlsTucked() {
    return this.#scrolledDown && this.isTopic;
  }

  @action
  registerViewsSlot(element) {
    this.mobileTabBar.viewsSlot = element;
  }

  @action
  unregisterViewsSlot() {
    this.mobileTabBar.viewsSlot = null;
  }

  @action
  resizeTrack([entry]) {
    this.followActiveTab(entry.target);
  }

  // Moves the highlight under the current section's tab: instantly the first
  // time, so it doesn't slide in from the edge, then sliding
  @action
  followActiveTab(track) {
    const tab = track.querySelector(".mobile-tab-bar__tab.--active");

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
      {{#if this.viewsTucked}}
        {{htmlClass "mobile-tab-bar-views-tucked"}}
      {{/if}}

      {{#let this.mobileTabBar.tabLayout as |layout|}}
        {{#if this.topicControlsTucked}}
          {{htmlClass
            (if
              layout.barTabs.length
              "mobile-tab-bar-tucked"
              "mobile-tab-bar-actions-tucked"
            )
          }}
        {{/if}}
        <nav
          aria-label={{i18n "mobile_tab_bar.label"}}
          class={{dConcatClass
            "mobile-tab-bar"
            (unless layout.barTabs.length "--no-tabs")
            (if this.capabilities.isAppWebview "--with-hub")
            (if this.isTopic "--topic")
            (if this.viewsTucked "--views-tucked")
            (if
              this.topicControlsTucked
              (if layout.barTabs.length "--tucked" "--actions-tucked")
            )
            (unless this.mobileTabBar.sectionTabKey "--no-section")
          }}
        >
          {{#unless layout.barTabs.length}}
            <MenuButton />
          {{/unless}}
          <div
            class="mobile-tab-bar__views"
            {{didInsert this.registerViewsSlot}}
            {{willDestroy this.unregisterViewsSlot}}
          ></div>
          {{#if layout.barTabs.length}}
            <div class="mobile-tab-bar__controls">
              <MenuButton />
              <div class="mobile-tab-bar__tabs" style={{this.tabsStyle}}>
                <div
                  class="mobile-tab-bar__track"
                  {{didInsert this.followActiveTab}}
                  {{dOnResize this.resizeTrack}}
                  {{didUpdate
                    this.followActiveTab
                    this.mobileTabBar.sectionTabKey
                    layout.barTabs
                  }}
                >
                  <span
                    aria-hidden="true"
                    class="mobile-tab-bar__highlight"
                  ></span>
                  {{#each layout.barTabs key="key" as |tab|}}
                    <Tab @tab={{tab}} />
                  {{/each}}
                  {{#if layout.moreTabs.length}}
                    <MoreTab />
                  {{/if}}
                </div>
              </div>
              <CreateButton />
            </div>
          {{else}}
            <CreateButton />
          {{/if}}
          {{#if this.capabilities.isAppWebview}}
            <DButton
              class="btn-default mobile-tab-bar__hub"
              @action={{this.mobileTabBar.returnToHub}}
              @ariaLabel="mobile_tab_bar.hub"
              @icon="eject"
              @title="mobile_tab_bar.hub"
            />
          {{/if}}
        </nav>
      {{/let}}
    {{/if}}
  </template>
}
