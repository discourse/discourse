import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";

<template>
  <li
    role="link"
    class="schema-setting-editor__tree-node --child"
    ...attributes
    {{on "click" @onChildClick}}
  >
    <div class="schema-setting-editor__tree-node-text">
      <span>{{@generateSchemaTitle @object @schema @index}}</span>
      {{icon "chevron-right"}}
    </div>
  </li>
</template>
