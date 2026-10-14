import AiDecisionModelsListEditor from "../../../../components/ai-decision-models-list-editor";

export default <template>
  <AiDecisionModelsListEditor
    @currentDecisionModel={{@controller.model}}
    @decisionModels={{@controller.allDecisionModels}}
  />
</template>
