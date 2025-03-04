import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
<template><DModal @title={{iN "fullscreen_table.view_table"}} @closeModal={{@closeModal}} class="fullscreen-table-modal -max">
  <:body>
    {{@model.tableHtml}}
  </:body>
</DModal></template>