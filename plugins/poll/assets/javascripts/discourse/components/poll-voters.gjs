import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";
import PollVotersRankedChoice from "./poll-voters-ranked-choice";

export default class PollVotersComponent extends Component {
  get showMore() {
    return this.args.voters.length < this.args.totalVotes;
  }

  <template>
    <div class="poll-voters">
      <ul class="poll-voters-list">
        {{#if @isRankedChoice}}
          <PollVotersRankedChoice @voters={{@voters}} />
        {{else}}
          {{#each @voters as |user|}}
            <li>
              <a data-user-card={{user.username}}>{{avatar
                  user.avatar_template
                  "tiny"
                  usernamePath=user.username
                  namePath=user.name
                  title=user.username
                }}</a>
            </li>
          {{/each}}
        {{/if}}
      </ul>
      {{#if this.showMore}}
        <ConditionalLoadingSpinner @condition={{@loading}}>
          <DButton
            @action={{fn @fetchVoters @optionId}}
            @icon="chevron-down"
            class="poll-voters-toggle-expand"
          />
        </ConditionalLoadingSpinner>
      {{/if}}
    </div>
  </template>
}
