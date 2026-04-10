import ExpressionWrapper from "./expression-wrapper";

<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <@field.Control />
  </ExpressionWrapper>
</template>
