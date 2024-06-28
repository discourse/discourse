import Component from "@glimmer/component";
import { service } from "@ember/service";
import ApiSection from "./api-section";
import FilterNoResults from "./filter-no-results";
import PanelHeader from "./panel-header";

export default class SidebarApiSections extends Component {
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

    return sectionConfigs.map((Section) => new Section());
  }

  <template>
    <PanelHeader @sections={{this.sections}} />

    {{#each this.sections as |section|}}
      <ApiSection @section={{section}} @collapsable={{@collapsable}} />
    {{/each}}

    <FilterNoResults />
  </template>
}
