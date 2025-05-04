import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

<template>
  <DButton
    class="mobile-search-button btn-transparent"
    title={{i18n "search.title"}}
    data-test-button="mobile-search"
    @action={{@onTap}}
    @icon="magnifying-glass"
  />
</template>
