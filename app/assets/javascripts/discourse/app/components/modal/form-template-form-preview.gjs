import DModal from "discourse/components/d-modal";
import Wrapper from "discourse/components/form-template-field/wrapper";
import iN from "discourse/helpers/i18n";
<template>
  <DModal
    @closeModal={{@closeModal}}
    @title={{iN "admin.form_templates.preview_modal.title"}}
    class="form-template-form-preview-modal"
  >
    <:body>
      <Wrapper @content={{@content}} />
    </:body>
  </DModal>
</template>
