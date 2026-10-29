import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import CreateButton from "discourse/components/mobile-tab-bar/create-button";
import MenuButton from "discourse/components/mobile-tab-bar/menu-button";
import Tab from "discourse/components/mobile-tab-bar/tab";
import htmlClass from "discourse/helpers/html-class";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class MobileTabBar extends Component {
  @service composer;
  @service mobileTabBar;

  @tracked moreBefore = false;
  @tracked moreAfter = false;

  get isVisible() {
    return this.mobileTabBar.enabled && !this.composer.isOpen;
  }

  @action
  onTrackScroll(event) {
    this.#updateEdges(event.target);
  }

  @action
  revealActiveTab(track) {
    track
      .querySelector(".mobile-tab-bar__tab.--active")
      ?.scrollIntoView({ block: "nearest", inline: "nearest" });
    this.#updateEdges(track);
  }

  // Fades the edges that have tabs scrolled past them
  #updateEdges(track) {
    const maxScroll = track.scrollWidth - track.clientWidth;
    this.moreBefore = track.scrollLeft > 1;
    this.moreAfter = track.scrollLeft < maxScroll - 1;
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

      <nav aria-label={{i18n "mobile_tab_bar.label"}} class="mobile-tab-bar">
        <MenuButton />
        <div class="mobile-tab-bar__tabs">
          <div
            class={{dConcatClass
              "mobile-tab-bar__track"
              (if this.moreBefore "--more-before")
              (if this.moreAfter "--more-after")
            }}
            {{didInsert this.revealActiveTab}}
            {{didUpdate this.revealActiveTab this.mobileTabBar.sectionTabKey}}
            {{on "scroll" this.onTrackScroll passive=true}}
          >
            {{#each this.mobileTabBar.tabs key="key" as |tab|}}
              <Tab @tab={{tab}} />
            {{/each}}
          </div>
        </div>
        <CreateButton />
      </nav>
    {{/if}}
  </template>
}
