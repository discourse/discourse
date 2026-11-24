import AiConceptsList from "discourse/plugins/discourse-ai/discourse/components/ai-concepts-list";

export default <template>
  <AiConceptsList
    @filter={{@controller.filter}}
    @model={{@controller.model}}
    @onQueryChange={{@controller.updateQuery}}
    @order={{@controller.order}}
    @status={{@controller.status}}
  />
</template>
