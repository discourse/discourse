import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import highlightSearch from "discourse/lib/highlight-search";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import htmlSafe from "discourse/helpers/html-safe";

export default class HighlightedSearch extends Component {
  @service search;

  @action
  highlight(element) {
    highlightSearch(element, this.search.activeGlobalSearchTerm);
  }
<template><span {{didInsert this.highlight}}>
  {{htmlSafe @string}}
</span></template>}
