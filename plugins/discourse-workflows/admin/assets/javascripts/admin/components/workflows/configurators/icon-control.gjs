import { not } from "discourse/truth-helpers";
import ExpressionWrapper from "./expression-wrapper";

export default <template>
  <ExpressionWrapper
    @field={{@field}}
    @schema={{@schema}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
    @dynamicValueHint={{@dynamicValueHint}}
    @session={{@session}}
  >
    <@field.Control @allowClear={{not @schema.required}} />
  </ExpressionWrapper>
</template>
