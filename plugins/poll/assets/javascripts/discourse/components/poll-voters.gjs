import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
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
              <a data-user-card={{user.username}} title={{user.username}}>
                {{dBoundAvatarTemplate user.avatar_template "tiny"}}
              </a>
            </li>
          {{/each}}
        {{/if}}
      </ul>
      {{#if this.showMore}}
        <DConditionalLoadingSpinner @condition={{@loading}}>
          <DButton
            @action={{fn @fetchVoters @optionId}}
            @icon="chevron-down"
            class="poll-voters-toggle-expand"
          />
        </DConditionalLoadingSpinner>
      {{/if}}
    </div>
  </template>
}
