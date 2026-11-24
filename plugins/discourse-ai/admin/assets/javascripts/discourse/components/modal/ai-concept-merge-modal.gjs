import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";
import AiConceptChooser from "discourse/plugins/discourse-ai/discourse/components/ai-concept-chooser";

export default class AiConceptMergeModal extends Component {
  @service toasts;

  @cached
  get formData() {
    return {
      target_concept_id: null,
    };
  }

  @action
  async submitMerge(data) {
    try {
      const response = await ajax(
        `/admin/plugins/discourse-ai/ai-concepts/${this.args.model.concept.id}/merge.json`,
        {
          type: "POST",
          contentType: "application/json",
          data: JSON.stringify({
            target_concept_id: Number(data.target_concept_id),
          }),
        }
      );

      this.toasts.success({
        data: {
          message: i18n("discourse_ai.concepts.merge.success", {
            target: response.ai_concept.name,
          }),
        },
        duration: "short",
      });

      this.args.model.onMerged?.(response.ai_concept);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="ai-concept-merge-modal"
      @closeModal={{@closeModal}}
      @title={{i18n
        "discourse_ai.concepts.merge.title"
        name=@model.concept.name
      }}
    >
      <:body>
        <p class="ai-concept-merge-modal__description">
          {{i18n "discourse_ai.concepts.merge.description"}}
        </p>

        <Form
          class="ai-concept-merge-modal__form"
          @data={{this.formData}}
          @onSubmit={{this.submitMerge}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="target_concept_id"
            @title={{i18n "discourse_ai.concepts.merge.target_label"}}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <AiConceptChooser
                class="ai-concept-merge-modal__target-chooser"
                @excludeId={{@model.concept.id}}
                @onChange={{field.set}}
                @options={{hash
                  clearable=false
                  none="discourse_ai.concepts.merge.target_placeholder"
                }}
                @value={{field.value}}
              />
            </field.Control>
          </form.Field>

          <form.Actions>
            <form.Submit
              class="btn-primary ai-concept-merge-modal__submit"
              @label="discourse_ai.concepts.merge.submit"
            />
            <DModalCancel @close={{@closeModal}} />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
