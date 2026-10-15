import AiDecisionModelEditorForm from "../../../../components/ai-decision-model-editor-form.gjs";

export default <template>
  <section class="admin-detail">
    <AiDecisionModelEditorForm
      @decisionModels={{@controller.allDecisionModels}}
      @model={{@controller.model}}
    />
  </section>
</template>
