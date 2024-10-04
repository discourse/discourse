import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import MoreSectionLink from "./more-section-link";
import SectionLinkButton from "./section-link-button";

export default class SidebarMoreSectionLinks extends Component {
  @service router;

  @tracked activeSectionLink;
  @tracked open = false;

  constructor() {
    super(...arguments);
    this.#setActiveSectionLink();
    this.router.on("routeDidChange", this, this.#setActiveSectionLink);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#removeClickEventListener();
    this.router.off("routeDidChange", this, this.#setActiveSectionLink);
  }

  get sectionLinks() {
    if (this.activeSectionLink) {
      return this.#filterActiveSectionLink(this.args.sectionLinks);
    } else {
      return this.args.sectionLinks;
    }
  }

  get secondarySectionLinks() {
    if (this.activeSectionLink) {
      return this.#filterActiveSectionLink(this.args.secondarySectionLinks);
    } else {
      return this.args.secondarySectionLinks;
    }
  }

  #filterActiveSectionLink(sectionLinks) {
    return sectionLinks.filter((sectionLink) => {
      return sectionLink.name !== this.activeSectionLink.name;
    });
  }

  @bind
  closeDetails(event) {
    if (event.target.closest(".sidebar-more-section-links-details-summary")) {
      return;
    }

    if (this.open) {
      const isLinkClick =
        event.target.className.includes("sidebar-section-link") ||
        event.target.className.includes("--link-button");

      if (isLinkClick || this.#isOutsideDetailsClick(event)) {
        this.open = false;
      }
    }
  }

  @action
  registerClickListener() {
    this.#addClickEventListener();
  }

  @action
  unregisterClickListener() {
    this.#removeClickEventListener();
  }

  @action
  toggleSectionLinks(event) {
    event.stopPropagation();
    this.open = !this.open;
  }

  #removeClickEventListener() {
    document.removeEventListener("click", this.closeDetails);
  }

  #addClickEventListener() {
    document.addEventListener("click", this.closeDetails);
  }

  #isOutsideDetailsClick(event) {
    return !event.composedPath().some((element) => {
      return element.className === "sidebar-more-section-links-details";
    });
  }

  #setActiveSectionLink() {
    this.activeSectionLink = this.args.sectionLinks.find((sectionLink) => {
      const args = [sectionLink.route];

      if (sectionLink.model) {
        args.push(sectionLink.model);
      } else if (sectionLink.models) {
        args.push(...sectionLink.models);
      }

      if (!isEmpty(sectionLink.query)) {
        args.push({ queryParams: sectionLink.query });
      }

      return this.router.isActive(...args) && sectionLink;
    });
  }

  <template>
    {{#if this.activeSectionLink}}
      <MoreSectionLink @sectionLink={{this.activeSectionLink}} />
    {{/if}}

    <li class="sidebar-section-link-wrapper">
      <DMenu
        @triggerClass="idebar-section-link sidebar-row sidebar-more-section-links-details-summary --link-button"
        @contentClass="sidebar-more-section-links-details-content"
        @modalForMobile={{true}}
        @autofocus={{true}}
      >
        <:trigger>
          <span class="sidebar-section-link-prefix icon">
            {{icon "ellipsis-vertical"}}
          </span>
          <span class="sidebar-section-link-content-text">
            {{i18n "sidebar.more"}}
          </span>
        </:trigger>

        <:content>
          <DropdownMenu as |dropdown|>
            {{#each this.sectionLinks as |sectionLink|}}
              <MoreSectionLink
                @sectionLink={{sectionLink}}
                class="dropdown-menu__item"
              />
            {{/each}}

            {{#if @moreButtonAction}}
              <dropdown.divider />

              <dropdown.item>
                <SectionLinkButton
                  @action={{@moreButtonAction}}
                  @icon={{@moreButtonIcon}}
                  @text={{@moreButtonText}}
                  @name="customize"
                />
              </dropdown.item>
            {{/if}}
          </DropdownMenu>
        </:content>
      </DMenu>
    </li>
  </template>
}
