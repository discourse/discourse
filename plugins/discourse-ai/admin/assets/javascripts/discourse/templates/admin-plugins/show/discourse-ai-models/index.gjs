import AiModelsList from "../../../../components/ai-models-list.gjs";

export default <template>
  <AiModelsList
    @decisionModels={{@controller.model.decisionModels}}
    @embeddings={{@controller.model.embeddings}}
    @llms={{@controller.model.llms}}
    @type={{@controller.type}}
  />
</template>
