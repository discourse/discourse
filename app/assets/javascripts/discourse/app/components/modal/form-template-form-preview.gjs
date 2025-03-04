import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
import Wrapper from "discourse/components/form-template-field/wrapper";
<template><DModal @closeModal={{@closeModal}} @title={{iN "admin.form_templates.preview_modal.title"}} class="form-template-form-preview-modal">
  <:body>
    <Wrapper @content={{@content}} />
  </:body>
</DModal></template>