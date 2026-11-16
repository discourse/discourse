import AiModelNew from "../../../../components/ai-model-new.gjs";

export default <template>
  <AiModelNew
    @decisionModels={{@controller.model.decisionModels}}
    @embeddings={{@controller.model.embeddings}}
    @llms={{@controller.model.llms}}
    @type={{@controller.type}}
  />
</template>
