import Component from "@ember/component";
import { concat } from "@ember/helper";
// should be kept in sync with 'UserSummary::MAX_SUMMARY_RESULTS'
import { LinkTo } from "@ember/routing";
import { tagName } from "@ember-decorators/component";
import iN from "discourse/helpers/i18n";
import discourseComputed from "discourse/lib/decorators";
const MAX_SUMMARY_RESULTS = 6;

@tagName("")
export default class UserSummaryTopicsList extends Component {
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
            @route={{concat "userActivity." @type}}
            @model={{@user}}
            class="more"
          >
            {{iN (concat "user.summary.more_" @type)}}
          </LinkTo>
        </p>
      {{/if}}
    {{else}}
      <p>{{iN (concat "user.summary.no_" @type)}}</p>
    {{/if}}
  </template>

  @discourseComputed("items.length")
  hasMore(length) {
    return length >= MAX_SUMMARY_RESULTS;
  }
}
