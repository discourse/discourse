import Component from "@glimmer/component";
import { service } from "@ember/service";
import formatAge from "discourse/helpers/format-age";
import htmlSafe from "discourse/helpers/html-safe";
import HighlightedSearch from "discourse/components/search-menu/highlighted-search";

export default class Blurb extends Component {
  @service siteSettings;
  @service site;
<template><span class="blurb">
  {{formatAge @result.created_at}}
  <span class="blurb__separator"> - </span>
  {{#if this.siteSettings.use_pg_headlines_for_excerpt}}
    <span>{{htmlSafe @result.blurb}}</span>
  {{else}}
    <span class="blurb__text">
      <HighlightedSearch @string={{@result.blurb}} />
    </span>
  {{/if}}
</span></template>}
