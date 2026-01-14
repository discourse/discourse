import DModal from "discourse/components/d-modal";
import Wrapper from "discourse/components/form-template-field/wrapper";
import { i18n } from "discourse-i18n";

const FormTemplateFormPreview = <template>
  <DModal
    @closeModal={{@closeModal}}
    @title={{i18n "admin.form_templates.preview_modal.title"}}
    class="form-template-form-preview-modal"
  >
    <:body>
      <Wrapper @content={{@content}} />
    </:body>
  </DModal>
</template>;

export default FormTemplateFormPreview;
