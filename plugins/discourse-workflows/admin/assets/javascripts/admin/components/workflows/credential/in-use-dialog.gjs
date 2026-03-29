import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

<template>
  <p>{{i18n "discourse_workflows.credentials.in_use_description"}}</p>

  <ul>
    {{#each @model.workflows as |workflow|}}
      <li>
        <LinkTo
          @route="adminPlugins.show.discourse-workflows.show"
          @model={{workflow.id}}
          {{on "click" @model.close}}
        >{{workflow.name}}</LinkTo>
      </li>
    {{/each}}
  </ul>
</template>
