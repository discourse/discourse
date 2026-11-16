import AiDecisionModelEditor from "../../../../components/ai-decision-model-editor.gjs";

export default <template>
  <AiDecisionModelEditor
    @decisionModels={{@controller.allDecisionModels}}
    @model={{@controller.model}}
  />
</template>
