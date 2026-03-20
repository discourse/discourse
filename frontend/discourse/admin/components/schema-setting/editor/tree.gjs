import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import TreeNode from "discourse/admin/components/schema-setting/editor/tree-node";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

<template>
  <ul class="schema-setting-editor__tree">
    {{#if @backButtonText}}
      <li
        role="link"
        class="schema-setting-editor__tree-node --back-btn"
        {{on "click" @clickBack}}
      >
        <div class="schema-setting-editor__tree-node-text">
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
      />
    {{/each}}

    <li class="schema-setting-editor__tree-node --parent --add-button">
      <DButton
        @action={{@addItem}}
        @translatedLabel={{@schema.name}}
        @icon="plus"
        class="btn-transparent schema-setting-editor__tree-add-button --root"
      />
    </li>
  </ul>
</template>
