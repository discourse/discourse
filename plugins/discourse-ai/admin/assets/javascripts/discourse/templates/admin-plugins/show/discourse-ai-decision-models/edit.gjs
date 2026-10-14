import AiDecisionModelEditorForm from "../../../../components/ai-decision-model-editor-form";
import AiDecisionModelsListEditor from "../../../../components/ai-decision-models-list-editor";

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
