import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import avatar from "discourse/helpers/bound-avatar-template";
import dIcon from "discourse-common/helpers/d-icon";

export default class PollVotersComponent extends Component {
  get showMore() {
    return this.args.voters.length < this.args.totalVotes;
  }

  get irvVoters() {
    let orderedVoters = [...this.args.voters];
    // debugger;

    orderedVoters.forEach((voter) => {
      if (voter.rank === 0) {
        voter.rank = "Abstain";
      }
    });

    orderedVoters.sort((a, b) => {
      if (a.rank > b.rank) {
        return 1;
      } else if (a.rank === b.rank) {
        if (a.user.username < b.user.username) {
          return -1;
        } else {
          return 1;
        }
      } else {
        return -1;
      }
    });

    // Group voters by rank
    const groupedObject = orderedVoters.reduce((groups, voter) => {
      const rank = voter.rank;
      if (!groups[rank]) {
        groups[rank] = [];
      }
      groups[rank].push(voter);
      return groups;
    }, {});

    const groupedVoters = Object.keys(groupedObject).map((rank) => ({
      rank,
      voters: groupedObject[rank],
    }));

    return groupedVoters;
  }
  <template>
    <div class="poll-voters">
      <ul class="poll-voters-list">
        {{#if @isIrv}}
          {{#each this.irvVoters as |rank|}}
            <ul>
              {{#if (eq rank.rank "Abstain")}}
                <span class="rank">{{dIcon "ban"}}</span>
              {{else}}
                <span class="rank">{{rank.rank}}</span>
              {{/if}}
              {{#each rank.voters as |user|}}
                <li>
                  {{avatar user.user.avatar_template "tiny"}}
                </li>
              {{/each}}
            </ul>
          {{/each}}
        {{else}}
          {{#each @voters as |user|}}
            <li>
              {{avatar user.avatar_template "tiny"}}
            </li>
          {{/each}}

        {{/if}}
      </ul>
      {{#if this.showMore}}
        {{#if @loading}}
          <div class="spinner small"></div>
        {{else}}
          <button
            {{on "click" (fn @fetchVoters @optionId)}}
            class="poll-voters-toggle-expand"
          >
            {{dIcon "chevron-down"}}
          </button>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
