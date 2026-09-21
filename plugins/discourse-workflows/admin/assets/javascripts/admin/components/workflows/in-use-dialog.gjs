import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

export default <template>
  <p>{{@model.description}}</p>

  {{#if @model.workflows.length}}
    <ul>
      {{#each @model.workflows as |workflow|}}
        <li>
          <LinkTo
            @model={{workflow.id}}
            @route="adminPlugins.show.discourse-workflows.show"
            {{on "click" @model.close}}
          >{{workflow.name}}</LinkTo>
          {{#if workflow.published}}
            ({{or
              @model.publishedLabel
              (i18n "discourse_workflows.published")
            }})
          {{/if}}
        </li>
      {{/each}}
    </ul>
  {{/if}}

  {{#each @model.additionalMessages as |message|}}
    <p>{{message}}</p>
  {{/each}}
</template>
