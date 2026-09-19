import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import curryComponent from "ember-curry-component";
import DMenu from "discourse/float-kit/components/d-menu";
import { findActiveLink } from "discourse/lib/sidebar/active-link";
import { and } from "discourse/truth-helpers";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import MoreSectionLink from "./more-section-link";
import MoreSectionTrigger from "./more-section-trigger";
import SectionLinkButton from "./section-link-button";

export default class SidebarMoreSectionLinks extends Component {
  @service router;

  @tracked activeSectionLink;

  constructor() {
    super(...arguments);
    this.#setActiveSectionLink();
    this.router.on("routeDidChange", this, this.#setActiveSectionLink);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this, this.#setActiveSectionLink);
  }

  get hoistActiveLink() {
    return this.args.hoistActiveLink ?? true;
  }

  get sectionLinks() {
    if (this.hoistActiveLink && this.activeSectionLink) {
      return this.#filterActiveSectionLink(this.args.sectionLinks);
    } else {
      return this.args.sectionLinks;
    }
  }

  get secondarySectionLinks() {
    if (this.hoistActiveLink && this.activeSectionLink) {
      return this.#filterActiveSectionLink(this.args.secondarySectionLinks);
    } else {
      return this.args.secondarySectionLinks;
    }
  }

  @cached
  get triggerComponent() {
    return curryComponent(
      MoreSectionTrigger,
      {
        text: this.args.triggerText,
        prefixType: this.args.triggerPrefixType,
        prefixValue: this.args.triggerPrefixValue,
        suffixType: this.args.triggerSuffixType,
        suffixValue: this.args.triggerSuffixValue,
      },
      getOwner(this)
    );
  }

  @action
  closeMenu(menu) {
    menu.close();

    if (this.args.toggleNavigationMenu) {
      this.args.toggleNavigationMenu();
    }
  }

  #filterActiveSectionLink(sectionLinks) {
    return sectionLinks.filter((sectionLink) => {
      return sectionLink.name !== this.activeSectionLink.name;
    });
  }

  #setActiveSectionLink() {
    this.activeSectionLink = findActiveLink(
      this.args.sectionLinks,
      this.router
    );
  }

  <template>
    {{#if (and this.hoistActiveLink this.activeSectionLink)}}
      <MoreSectionLink
        @scrollIntoView={{@scrollActiveLinkIntoView}}
        @sectionLink={{this.activeSectionLink}}
      />
    {{/if}}

    <li class="sidebar-section-link-wrapper">
      <DMenu
        @autofocus={{true}}
        @identifier={{if @identifier @identifier "sidebar-more-section"}}
        @inline={{true}}
        @modalForMobile={{true}}
        @placement="bottom"
        @triggerClass="sidebar-section-link sidebar-more-section-links-details-summary sidebar-row --link-button"
        @triggerComponent={{this.triggerComponent}}
      >

        <:content as |menu|>
          <DDropdownMenu as |dropdown|>
            {{#each this.sectionLinks as |sectionLink|}}
              <MoreSectionLink
                class="dropdown-menu__item"
                @sectionLink={{sectionLink}}
                {{on "click" (fn this.closeMenu menu)}}
              />
            {{/each}}

            {{#if @moreButtonAction}}
              <dropdown.divider />

              <dropdown.item>
                <SectionLinkButton
                  @action={{@moreButtonAction}}
                  @icon={{@moreButtonIcon}}
                  @name="customize"
                  @text={{@moreButtonText}}
                  @toggleNavigationMenu={{@toggleNavigationMenu}}
                />
              </dropdown.item>
            {{/if}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    </li>
  </template>
}
