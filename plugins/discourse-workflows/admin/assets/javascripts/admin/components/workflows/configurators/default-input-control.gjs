import ExpressionWrapper from "./expression-wrapper";

<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
    @dynamicValueHint={{@dynamicValueHint}}
    @session={{@session}}
  >
    <@field.Control placeholder={{@placeholder}} />
  </ExpressionWrapper>
</template>
