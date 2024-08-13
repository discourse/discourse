import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import BaseCustomSidebarSection from "../../lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "../../lib/sidebar/base-custom-sidebar-section-link";
import ApiSection from "./api-section";
import PanelHeader from "./panel-header";

export default class SidebarApiSections extends Component {
  @service router;
  @service sidebarState;

  get sections() {
    let sectionConfigs;

    if (this.sidebarState.combinedMode) {
      sectionConfigs = this.sidebarState.panels
        .filter((panel) => !panel.hidden)
        .flatMap((panel) => panel.sections);
    } else {
      sectionConfigs = this.sidebarState.currentPanel.sections;
    }

    return sectionConfigs.map((SectionClass) =>
      initializeSection(SectionClass, {
        routerService: this.router,
        sidebarState: this.sidebarState,
        owner: this,
      })
    );
  }

  get filteredSections() {
    return this.sections.filter((section) => section.filtered);
  }

  <template>
    <PanelHeader @sections={{this.filteredSections}} />

    {{#each this.filteredSections as |section|}}
      <ApiSection
        @section={{section}}
        @collapsable={{@collapsable}}
        @expandWhenActive={{@expandActiveSection}}
        @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
      />
    {{/each}}
  </template>
}

function initializeSection(SectionClass, opts) {
  const { sidebarState, owner } = opts;

  const SidebarSection = prepareSidebarSectionClass(SectionClass, opts);

  const sectionInstance = new SidebarSection({
    filterable:
      !sidebarState.combinedMode && sidebarState.currentPanel.filterable,
    sidebarState,
  });

  setOwner(sectionInstance, getOwner(owner));

  return sectionInstance;
}

// extends the class provided for the section to add functionality we don't want to be overridable when defining custom
// sections using the plugin API, like for example the filtering capabilities
function prepareSidebarSectionClass(SectionClass, opts) {
  const { routerService, level = 0 } = opts;

  return class extends SectionClass {
    #level;

    constructor({ filterable, sidebarState }) {
      super();

      this.filterable = filterable;
      this.sidebarState = sidebarState;
      this.#level = level;
    }

    get level() {
      return this.#level;
    }

    @cached
    get links() {
      return super.links.map((item) => {
        return item instanceof BaseCustomSidebarSectionLink
          ? item
          : initializeSection(item, {
              ...opts,
              level: level + 1,
            });
      });
    }

    @cached
    get filteredLinks() {
      if (!this.filterable || !this.sidebarState.filter) {
        return this.links;
      }

      if (this.text?.toLowerCase()?.match(this.sidebarState.sanitizedFilter)) {
        return this.links;
      }

      return this.links.filter((item) => {
        // subsection
        if (item instanceof BaseCustomSidebarSection) {
          return item.filteredLinks.length > 0;
        }

        // standard link
        return (
          item.text
            .toString()
            .toLowerCase()
            .match(this.sidebarState.sanitizedFilter) ||
          item.keywords.navigation.some((keyword) =>
            keyword.match(this.sidebarState.sanitizedFilter)
          )
        );
      });
    }

    get activeLink() {
      return this.filteredLinks.find((link) => {
        try {
          const currentWhen = link.currentWhen;

          if (typeof currentWhen === "boolean") {
            return currentWhen;
          }

          // TODO detect active links using the href field

          const queryParams = link.query || {};
          let models;

          if (link.model) {
            models = [link.model];
          } else if (link.models) {
            models = link.models;
          } else {
            models = [];
          }

          if (typeof currentWhen === "string") {
            return currentWhen.split(" ").some((route) =>
              routerService.isActive(route, ...models, {
                queryParams,
              })
            );
          }

          return routerService.isActive(link.route, ...models, {
            queryParams,
          });
        } catch (e) {
          // false if ember throws an exception while checking the routes
          return false;
        }
      });
    }

    get filtered() {
      return !this.filterable || this.filteredLinks?.length > 0;
    }
  };
}
