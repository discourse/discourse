import iN from "discourse/helpers/i18n";
import { on } from "@ember/modifier";
import dIcon from "discourse/helpers/d-icon";
<template><a class="clear-search" aria-label="clear_input" title={{iN "search.clear_search"}} href {{on "click" @clearSearch}}>
  {{dIcon "xmark"}}
</a></template>