<DModal
  @closeModal={{@closeModal}}
  @title={{i18n "admin.form_templates.preview_modal.title"}}
  class="form-template-form-preview-modal"
>
  <:body>
    <FormTemplateField::Wrapper @content={{@content}} />
  </:body>
</DModal>