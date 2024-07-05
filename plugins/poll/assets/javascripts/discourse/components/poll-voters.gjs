import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";

export default class PollVotersComponent extends Component {
  get showMore() {
    return this.args.voters.length < this.args.totalVotes;
  }

  <template>
    <div class="poll-voters">
      <ul class="poll-voters-list">
        {{#each @voters as |user|}}
          <li>
            {{avatar user.avatar_template "tiny"}}
          </li>
        {{/each}}
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
