import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { LinkTo } from "@ember/routing";
import { hash } from "@ember/helper";

@tagName("")
export default class UserSummaryCategorySearch extends Component {
  @discourseComputed("user", "category")
  searchParams() {
    let query = `@${this.get("user.username")} #${this.get("category.slug")}`;
    if (this.searchOnlyFirstPosts) {
      query += " in:first";
    }
    return query;
  }
<template>{{#if @count}}
  <LinkTo @route="full-page-search" @query={{hash q=this.searchParams}}>
    {{@count}}
  </LinkTo>
{{else}}
  &ndash;
{{/if}}</template>}
