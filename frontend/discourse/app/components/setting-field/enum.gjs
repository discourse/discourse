import { or } from "discourse/truth-helpers";

<template>
  <@field.Control as |select|>
    {{#each (or @definition.valid_values @definition.choices) as |choice|}}
      <select.Option @value={{choice.value}}>
        {{choice.name}}
      </select.Option>
    {{/each}}
  </@field.Control>
</template>
