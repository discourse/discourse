import { on } from "@ember/modifier";
import dIcon from "discourse/helpers/d-icon";

<template>
  <li
    role="link"
    class="schema-theme-setting-editor__tree-node --child"
    ...attributes
    {{on "click" @onChildClick}}
  >
    <div class="schema-theme-setting-editor__tree-node-text">
      <span>{{@generateSchemaTitle @object @schema @index}}</span>
      {{dIcon "chevron-right"}}
    </div>
  </li>
</template>
