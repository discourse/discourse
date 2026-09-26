import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

// The controls above the list: what to search for, which of the two builds to
// show, and whether to count anything the browser did not fetch.
export default <template>
  <div class="ba-toolbar">
    <DFilterInput
      placeholder={{@placeholder}}
      @filterAction={{@onFilter}}
      @icons={{hash left="magnifying-glass"}}
      @value={{@filter}}
    />
    <DNativeSelect
      @includeNone={{false}}
      @onChange={{@onScope}}
      @value={{@scope}}
      as |select|
    >
      <select.Option @value="all">{{i18n
          "dev_tools.bundle_analyzer.scope_all"
        }}</select.Option>
      <select.Option @value="core">{{i18n
          "dev_tools.bundle_analyzer.scope_core"
        }}</select.Option>
      <select.Option @value="plugins">{{i18n
          "dev_tools.bundle_analyzer.scope_plugins"
        }}</select.Option>
    </DNativeSelect>
    <DToggleSwitch
      @label="dev_tools.bundle_analyzer.only_loaded"
      @state={{@view.onlyLoaded}}
      {{on "click" @view.toggle}}
    />
  </div>
</template>
