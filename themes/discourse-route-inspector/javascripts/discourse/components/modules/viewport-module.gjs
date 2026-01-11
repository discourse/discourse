import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DataSection from "../data-section";

export default class ViewportModule extends Component {
  @service capabilities;

  get rawData() {
    return {
      sm: this.capabilities.viewport.sm,
      md: this.capabilities.viewport.md,
      lg: this.capabilities.viewport.lg,
      xl: this.capabilities.viewport.xl,
      "2xl": this.capabilities.viewport["2xl"],
    };
  }

  <template>
    <DataSection
      @sectionKey="capabilities.viewport"
      @label={{i18n (themePrefix "route_inspector.viewport")}}
      @icon="lucide-monitor"
      @rawData={{this.rawData}}
      @tableKey="viewport"
      @isSectionCollapsed={{@isSectionCollapsed}}
      @onToggleSection={{@onToggleSection}}
      @onDrillInto={{@onDrillInto}}
    />
  </template>
}
