import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

<template>
  <DButton
    class="show-advanced-search btn-transparent"
    title={{i18n "search.open_advanced"}}
    @action={{@openAdvancedSearch}}
    @icon="sliders"
  />
</template>
