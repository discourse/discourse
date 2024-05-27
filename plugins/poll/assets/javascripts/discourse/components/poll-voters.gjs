import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse-common/helpers/d-icon";

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
            {{on "click" (fn @fetchVoters @optionId)}}
            class="poll-voters-toggle-expand"
          >
            {{icon "chevron-down"}}
          </DButton>
        </ConditionalLoadingSpinner>
      {{/if}}
    </div>
  </template>
}
