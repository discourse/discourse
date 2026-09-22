import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

// The controls above a report: what to search for, and whether to count
// anything the browser did not fetch.
export default <template>
  <div class="ba-toolbar">
    <DFilterInput
      placeholder={{@placeholder}}
      @filterAction={{@onFilter}}
      @icons={{hash left="magnifying-glass"}}
      @value={{@filter}}
    />
    <DToggleSwitch
      @label="dev_tools.bundle_analyzer.only_loaded"
      @state={{@view.onlyLoaded}}
      {{on "click" @view.toggle}}
    />
  </div>
</template>
