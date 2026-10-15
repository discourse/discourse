import AiDecisionModelEditorForm from "../../../../components/ai-decision-model-editor-form.gjs";
import AiDecisionModelsListEditor from "../../../../components/ai-decision-models-list-editor.gjs";

export default <template>
  {{#if @controller.model}}
    <section class="admin-detail">
      <AiDecisionModelEditorForm
        @decisionModels={{@controller.allDecisionModels}}
        @model={{@controller.model}}
      />
    </section>
  {{else}}
    <AiDecisionModelsListEditor
      @decisionModels={{@controller.allDecisionModels}}
    />
  {{/if}}
</template>
