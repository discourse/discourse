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
    <@field.Control />
  </ExpressionWrapper>
</template>
