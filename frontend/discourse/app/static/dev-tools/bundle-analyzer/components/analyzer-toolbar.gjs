import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

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
      <select.Option @value="all">Core and plugins</select.Option>
      <select.Option @value="core">Core only</select.Option>
      <select.Option @value="plugins">Plugins only</select.Option>
    </DNativeSelect>
    <DToggleSwitch
      @state={{@view.onlyLoaded}}
      @translatedLabel="Only show loaded chunks"
      {{on "click" @view.toggle}}
    />
  </div>
</template>
