import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ExpressionWrapper from "./expression-wrapper";

<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <CategoryChooser @value={{@field.value}} @onChange={{@field.set}} />
  </ExpressionWrapper>
</template>
