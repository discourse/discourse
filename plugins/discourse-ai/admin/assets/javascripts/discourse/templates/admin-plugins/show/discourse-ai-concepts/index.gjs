import AiConceptsList from "discourse/plugins/discourse-ai/discourse/components/ai-concepts-list";

export default <template>
  <AiConceptsList
    @filter={{@controller.model.queryParams.filter}}
    @model={{@controller.model}}
    @order={{@controller.model.queryParams.order}}
    @status={{@controller.model.queryParams.status}}
  />
</template>
