import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
import htmlSafe from "discourse/helpers/html-safe";
<template><DModal @title={{iN "log_in"}} @closeModal={{@closeModal}}>
  <:body>
    {{htmlSafe (iN "login.sent_activation_email_again" currentEmail=@model.currentEmail)}}
  </:body>
</DModal></template>