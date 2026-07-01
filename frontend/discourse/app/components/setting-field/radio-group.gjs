import { or } from "discourse/truth-helpers";

<template>
  <@field.Control as |radioGroup|>
    {{#each (or @definition.valid_values @definition.choices) as |choice|}}
      <radioGroup.Radio @value={{choice.value}}>
        {{choice.name}}
      </radioGroup.Radio>
    {{/each}}
  </@field.Control>
</template>
