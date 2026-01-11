import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { computeLong } from "../lib/compute-long";
import { filterData } from "../lib/filter-data";
import { getDefaultCollapsed } from "../lib/inspector-section-config";
import InspectorDataTable from "./inspector-data-table";
import InspectorSection from "./inspector-section";

export default class DataSection extends Component {
  @service routeInspectorState;

  get sectionKey() {
    return this.args.sectionKey;
  }

  get defaultCollapsed() {
    return getDefaultCollapsed(this.sectionKey);
  }

  get filteredData() {
    if (!this.args.rawData) {
      return {};
    }
    return filterData(this.args.rawData, this.routeInspectorState.filter, this.routeInspectorState.filterCaseSensitive);
  }

  get isLong() {
    return computeLong(this.filteredData);
  }

  get isCollapsed() {
    if (this.args.forceCollapsed !== undefined) {
      return this.args.forceCollapsed;
    }
    return this.args.isSectionCollapsed(this.sectionKey, this.defaultCollapsed);
  }

  <template>
    <InspectorSection
      @label={{@label}}
      @icon={{@icon}}
      @long={{this.isLong}}
      @sectionKey={{this.sectionKey}}
      @defaultCollapsed={{this.defaultCollapsed}}
      @isCollapsed={{this.isCollapsed}}
      @onToggle={{fn @onToggleSection this.sectionKey this.defaultCollapsed}}
    >
      <InspectorDataTable
        @data={{this.filteredData}}
        @tableKey={{@tableKey}}
        @onDrillInto={{@onDrillInto}}
      />
    </InspectorSection>
  </template>
}
