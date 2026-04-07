import DSegmentedControl from "discourse/components/d-segmented-control";
import ExpressionInput from "./expression-input";

const ExpressionWrapper = <template>
  <div class="workflows-property-engine__control-wrapper">
    {{#if @expressionMode}}
      <ExpressionInput
        @field={{@field}}
        @placeholder={{@placeholder}}
        @autofocus={{true}}
      />
    {{else}}
      {{yield}}
    {{/if}}

    {{#if @supportsExpression}}
      <DSegmentedControl
        @items={{@modeItems}}
        @value={{if @expressionMode "dynamic" "plain"}}
        @onSelect={{@onModeChange}}
        @size="small"
        class="workflows-property-engine__mode-control"
      />
    {{/if}}
  </div>
</template>;

export default ExpressionWrapper;
