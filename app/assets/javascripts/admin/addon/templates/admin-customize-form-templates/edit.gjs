import Form from "admin/components/form-template/form";
import InfoHeader from "admin/components/form-template/info-header";

<template>
  <div class="edit-form-template">
    <InfoHeader />
    <Form @model={{@controller.model}} />
  </div>
</template>
