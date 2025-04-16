import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

<template>
  <DButton
    class="btn-transparent clear-search"
    data-test-button="clear-search-input"
    aria-label="clear_input"
    title={{i18n "search.clear_search"}}
    @action={{@clearSearch}}
    @icon="xmark"
  />
</template>
