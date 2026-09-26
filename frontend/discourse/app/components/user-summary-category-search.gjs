/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { computed } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "discourse/lib/service";
import { tagName } from "@ember-decorators/component";
import SiteService from "discourse/services/site";

@tagName("")
export default class UserSummaryCategorySearch extends Component {
  @service(() => SiteService) site;

  @computed("user", "category")
  get searchParams() {
    let query = `@${this.get("user.username")} #${this.get("category.slug")}`;
    if (this.searchOnlyFirstPosts) {
      query += " in:first";
    }
    return query;
  }

  <template>
    {{#if @count}}
      {{#if this.site.can_search}}
        <LinkTo @query={{hash q=this.searchParams}} @route="full-page-search">
          {{@count}}
        </LinkTo>
      {{else}}
        {{@count}}
      {{/if}}
    {{else}}
      &ndash;
    {{/if}}
  </template>
}
