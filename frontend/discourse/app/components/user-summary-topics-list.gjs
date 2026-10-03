import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

// should be kept in sync with 'UserSummary::MAX_SUMMARY_RESULTS'
const MAX_SUMMARY_RESULTS = 6;

export default class UserSummaryTopicsList extends Component {
  get hasMore() {
    return this.args.items?.length >= MAX_SUMMARY_RESULTS;
  }

  <template>
    {{#if @items}}
      <ul>
        {{#each @items as |item|}}
          {{yield item}}
        {{/each}}
      </ul>
      {{#if this.hasMore}}
        <p>
          <LinkTo
            class="more"
            @model={{@user}}
            @route={{concat "userActivity." @type}}
          >
            {{i18n (concat "user.summary.more_" @type)}}
          </LinkTo>
        </p>
      {{/if}}
    {{else}}
      <p>{{i18n (concat "user.summary.no_" @type)}}</p>
    {{/if}}
  </template>
}
