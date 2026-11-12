import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";

export default <template>
  <p>{{@model.description}}</p>

  <ul>
    {{#each @model.workflows as |workflow|}}
      <li>
        <LinkTo
          @model={{workflow.id}}
          @route="adminPlugins.show.discourse-workflows.show"
          {{on "click" @model.close}}
        >{{workflow.name}}</LinkTo>
      </li>
    {{/each}}
  </ul>
</template>
