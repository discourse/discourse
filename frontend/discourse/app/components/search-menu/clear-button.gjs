import { on } from "@ember/modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <a
    class="clear-search"
    aria-label="clear_input"
    title={{i18n "search.clear_search"}}
    href
    {{on "click" @clearSearch}}
  >
    {{dIcon "xmark"}}
  </a>
</template>
