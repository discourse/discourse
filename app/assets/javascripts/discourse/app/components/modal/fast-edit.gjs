import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
import FastEdit from "discourse/components/fast-edit";
<template><DModal @title={{iN "post.quote_edit"}} @closeModal={{@closeModal}}>
  <FastEdit @newValue={{@model.newValue}} @initialValue={{@model.initialValue}} @post={{@model.post}} @close={{@closeModal}} />
</DModal></template>