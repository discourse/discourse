import { not } from "discourse/truth-helpers";
import ExpressionWrapper from "./expression-wrapper";

export default <template>
  <ExpressionWrapper
    @dynamicValueHint={{@dynamicValueHint}}
    @field={{@field}}
    @placeholder={{@placeholder}}
    @schema={{@schema}}
    @session={{@session}}
    @supportsExpression={{@supportsExpression}}
  >
    <@field.Control @allowClear={{not @schema.required}} />
  </ExpressionWrapper>
</template>
