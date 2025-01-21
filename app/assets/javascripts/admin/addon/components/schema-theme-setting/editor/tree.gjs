import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import dIcon from "discourse/helpers/d-icon";
import TreeNode from "admin/components/schema-theme-setting/editor/tree-node";

<template>
  <ul class="schema-theme-setting-editor__tree">
    {{#if @backButtonText}}
      <li
        role="link"
        class="schema-theme-setting-editor__tree-node --back-btn"
        {{on "click" @clickBack}}
      >
        <div class="schema-theme-setting-editor__tree-node-text">
          {{dIcon "arrow-left"}}
          {{@backButtonText}}
        </div>
      </li>
    {{/if}}

    {{#each @data as |object index|}}
      <TreeNode
        @index={{index}}
        @object={{object}}
        @active={{eq @activeIndex index}}
        @onClick={{fn @updateIndex index}}
        @onChildClick={{@onChildClick}}
        @schema={{@schema}}
        @addChildItem={{@addChildItem}}
        @generateSchemaTitle={{@generateSchemaTitle}}
        @registerInputFieldObserver={{@registerInputFieldObserver}}
        @unregisterInputFieldObserver={{@unregisterInputFieldObserver}}
      />
    {{/each}}

    <li class="schema-theme-setting-editor__tree-node --parent --add-button">
      <DButton
        @action={{@addItem}}
        @translatedLabel={{@schema.name}}
        @icon="plus"
        class="btn-transparent schema-theme-setting-editor__tree-add-button --root"
      />
    </li>
  </ul>
</template>
