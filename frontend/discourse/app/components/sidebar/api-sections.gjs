import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isActiveLink } from "discourse/lib/sidebar/active-link";
import ApiSection from "./api-section.gjs";
import PanelHeader from "./panel-header.gjs";

export default class SidebarApiSections extends Component {
  @service router;
  @service sidebarState;

  @cached
  get sections() {
    let sectionConfigs;

    if (this.sidebarState.combinedMode) {
      sectionConfigs = this.sidebarState.panels
        .filter((panel) => !panel.hidden)
        .flatMap((panel) => panel.sections);
    } else {
      sectionConfigs = this.sidebarState.currentPanel.sections;
    }

    const options = {
      filterable:
        !this.sidebarState.combinedMode &&
        this.sidebarState.currentPanel.filterable,
      owner: getOwner(this),
      router: this.router,
      sidebarState: this.sidebarState,
    };

    return sectionConfigs.map((Section) => prepareSection(Section, options));
  }

  get filteredSections() {
    return this.sections.filter((section) => section.filtered);
  }

  <template>
    <PanelHeader
      @filteredSections={{this.filteredSections}}
      @sections={{this.sections}}
    />

    {{#each this.filteredSections key="name" as |section|}}
      <ApiSection
        @collapsable={{@collapsable}}
        @expandWhenActive={{@expandActiveSection}}
        @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
        @section={{section}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />
    {{/each}}
  </template>
}

function prepareSection(Section, options, parent) {
  const { filterable, owner, router, sidebarState } = options;

  class PreparedSection extends Section {
    get sectionKey() {
      return parent ? `${parent.sectionKey}/${this.name}` : this.name;
    }

    @cached
    get sidebarItems() {
      const items =
        this.items ?? this.links?.map((link) => ({ type: "link", link })) ?? [];

      return items.map((item) => {
        if (item.type === "section") {
          const section = prepareSection(item.section, options, this);
          return { type: "section", key: `section:${section.name}`, section };
        }
        return { type: "link", key: `link:${item.link.name}`, link: item.link };
      });
    }

    @cached
    get childSections() {
      return this.sidebarItems
        .filter((item) => item.type === "section")
        .map((item) => item.section);
    }

    @cached
    get filteredItems() {
      return this.sidebarItems.filter((item) => {
        if (item.type === "section") {
          return item.section.filtered;
        }
        return this.#showAllLinks || this.#matchesLink(item.link);
      });
    }

    @cached
    get filteredMoreLinks() {
      const links = this.moreLinks ?? [];
      return this.#showAllLinks
        ? links
        : links.filter((link) => this.#matchesLink(link));
    }

    @cached
    get activeLink() {
      for (const item of this.filteredItems) {
        if (item.type === "section") {
          if (item.section.activeLink) {
            return item.section.activeLink;
          }
        } else if (isActiveLink(item.link, router)) {
          return item.link;
        }
      }

      return this.filteredMoreLinks.find((link) => isActiveLink(link, router));
    }

    get filtered() {
      return (
        this.displaySection !== false &&
        (!filterable ||
          this.filteredItems.length > 0 ||
          this.filteredMoreLinks.length > 0)
      );
    }

    @cached
    get matchesSectionFilter() {
      return (
        parent?.matchesSectionFilter ||
        this.text?.toLowerCase().match(sidebarState.sanitizedFilter)
      );
    }

    get #showAllLinks() {
      return !filterable || !sidebarState.filter || this.matchesSectionFilter;
    }

    #matchesLink(link) {
      const filter = sidebarState.sanitizedFilter;
      return (
        link.text.toString().toLowerCase().match(filter) ||
        link.keywords?.navigation?.some((keyword) => keyword.match(filter))
      );
    }
  }

  const section = new PreparedSection();
  setOwner(section, owner);
  return section;
}
