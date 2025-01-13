import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
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
      <button
        {{on "click" this.toggleSectionLinks}}
        aria-expanded={{if this.open "true" "false"}}
        class="sidebar-section-link sidebar-row sidebar-more-section-links-details-summary --link-button"
      >
        <span class="sidebar-section-link-prefix icon">
          {{icon "ellipsis-vertical"}}
        </span>
        <span class="sidebar-section-link-content-text">
          {{i18n "sidebar.more"}}
        </span>
      </button>
    </li>

    {{#if this.open}}
      <div class="sidebar-more-section-links-details">
        <div
          {{didInsert this.registerClickListener}}
          {{willDestroy this.unregisterClickListener}}
          class="sidebar-more-section-links-details-content-wrapper"
        >

          <div class="sidebar-more-section-links-details-content">
            <ul class="sidebar-more-section-links-details-content-main">
              {{#each this.sectionLinks as |sectionLink|}}
                <MoreSectionLink @sectionLink={{sectionLink}} />
              {{/each}}
            </ul>

            {{#if @moreButtonAction}}
              <div class="sidebar-more-section-links-details-content-footer">
                <SectionLinkButton
                  @action={{@moreButtonAction}}
                  @icon={{@moreButtonIcon}}
                  @text={{@moreButtonText}}
                  @name="customize"
                />
              </div>
            {{/if}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
