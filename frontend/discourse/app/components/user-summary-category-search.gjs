import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";

export default class UserSummaryCategorySearch extends Component {
  @service site;

  get searchParams() {
    let query = `@${this.args.user?.username} #${this.args.category?.slug}`;
    if (this.args.searchOnlyFirstPosts) {
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
