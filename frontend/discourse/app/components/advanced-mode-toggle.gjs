import DButton from "discourse/ui-kit/d-button";

const AdvancedModeToggle = <template>
  <DButton
    class="btn-default advanced-mode-btn{{if @active ' --active'}}"
    @icon="gear"
    @label={{if
      @active
      "advanced_mode_toggle.simple_mode"
      "advanced_mode_toggle.advanced_mode"
    }}
    @action={{@onToggle}}
    ...attributes
  />
</template>;

export default AdvancedModeToggle;
