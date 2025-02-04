import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
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

    return sectionConfigs.map((Section) => {
      const SidebarSection = prepareSidebarSectionClass(Section, this.router);

      const sectionInstance = new SidebarSection({
        filterable:
          !this.sidebarState.combinedMode &&
          this.sidebarState.currentPanel.filterable,
        sidebarState: this.sidebarState,
      });

      setOwner(sectionInstance, getOwner(this));

      return sectionInstance;
    });
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

// extends the class provided for the section to add functionality we don't want to be overridable when defining custom
// sections using the plugin API, like for example the filtering capabilities
function prepareSidebarSectionClass(Section, routerService) {
  return class extends Section {
    constructor({ filterable, sidebarState }) {
      super();

      this.filterable = filterable;
      this.sidebarState = sidebarState;
    }

    @cached
    get filteredLinks() {
      if (!this.filterable || !this.sidebarState.filter) {
        return this.links;
      }

      if (this.text?.toLowerCase()?.match(this.sidebarState.sanitizedFilter)) {
        return this.links;
      }

      return this.links.filter((link) => {
        return (
          link.text
            .toString()
            .toLowerCase()
            .match(this.sidebarState.sanitizedFilter) ||
          link.keywords.navigation.some((keyword) =>
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
        } catch {
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
