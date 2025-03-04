import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
<template><DModal @closeModal={{@closeModal}} @title={{iN "review.approval.title"}} class="post-enqueued-modal">
  <:body>
    <p>{{iN "review.approval.description"}}</p>
    <p>
      {{htmlSafe (iN "review.approval.pending_posts" count=@model.pending_count)}}
    </p>
  </:body>
  <:footer>
    <DButton @action={{@closeModal}} class="btn-primary" @label="review.approval.ok" />
  </:footer>
</DModal></template>