import Component from "@glimmer/component";
import { service } from "@ember/service";
import AdminHeader from "./admin-header";
import ApiSection from "./api-section";
import FilterNoResults from "./filter-no-results";

export default class SidebarApiSections extends Component {
  @service sidebarState;

  get sections() {
    if (this.sidebarState.combinedMode) {
      return this.sidebarState.panels
        .filter((panel) => !panel.hidden)
        .flatMap((panel) => panel.sections);
    } else {
      return this.sidebarState.currentPanel.sections;
    }
  }

  <template>
    <AdminHeader />

    {{#each this.sections as |sectionConfig|}}
      <ApiSection
        @sectionConfig={{sectionConfig}}
        @collapsable={{@collapsable}}
      />
    {{/each}}

    <FilterNoResults />
  </template>
}
