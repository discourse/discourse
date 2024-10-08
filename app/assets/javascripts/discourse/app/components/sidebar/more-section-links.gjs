import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
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
        @triggerClass="sidebar-section-link sidebar-row sidebar-more-section-links-details-summary --link-button"
        @contentClass="sidebar-more-section-links-details-content"
        @modalForMobile={{true}}
        @autofocus={{true}}
        @placement="bottom"
        @inline={{true}}
      >
        <:trigger>
          <span class="sidebar-section-link-prefix icon">
            {{icon "ellipsis-vertical"}}
          </span>
          <span class="sidebar-section-link-content-text">
            {{i18n "sidebar.more"}}
          </span>
        </:trigger>

        <:content as |menu|>
          <DropdownMenu as |dropdown|>
            {{#each this.sectionLinks as |sectionLink|}}
              <MoreSectionLink
                @sectionLink={{sectionLink}}
                class="dropdown-menu__item"
                {{on "click" menu.close}}
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
                  @close={{menu.close}}
                />
              </dropdown.item>
            {{/if}}
          </DropdownMenu>
        </:content>
      </DMenu>
    </li>
  </template>
}
