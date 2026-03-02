/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { computed } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class UserSummaryCategorySearch extends Component {
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
      <LinkTo @route="full-page-search" @query={{hash q=this.searchParams}}>
        {{@count}}
      </LinkTo>
    {{else}}
      &ndash;
    {{/if}}
  </template>
}
