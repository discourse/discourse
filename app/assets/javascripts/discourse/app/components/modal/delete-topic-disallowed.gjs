import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
<template><DModal @closeModal={{@closeModal}}>
  <:body>
    <p>{{htmlSafe (iN "post.controls.delete_topic_disallowed_modal")}}</p>
  </:body>
  <:footer>
    <DButton @action={{@closeModal}} class="btn-primary" @label="close" />
  </:footer>
</DModal></template>