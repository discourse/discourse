import DButton from "discourse/components/d-button";
import iN from "discourse/helpers/i18n";
<template><DButton class="show-advanced-search btn-transparent" title={{iN "search.open_advanced"}} @action={{@openAdvancedSearch}} @icon="sliders" /></template>