import Component from "@glimmer/component";
import { eq } from "discourse/truth-helpers";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class PollVotersComponent extends Component {
  groupVotersByRank = (voters) => {
    return voters.reduce((groups, voter) => {
      const rank = voter.rank;
      groups[rank] ??= [];
      groups[rank].push(voter);
      return groups;
    }, {});
  };

  get rankedChoiceVoters() {
    const voters = [...this.args.voters];

    // Group voters by rank so they can be displayed together by rank
    const groupedByRank = this.groupVotersByRank(voters);

    // Convert groups to array of objects with keys rank and voters
    const groupedVoters = Object.keys(groupedByRank).map((rank) => ({
      rank,
      voters: groupedByRank[rank],
    }));

    return groupedVoters;
  }

  <template>
    {{#each this.rankedChoiceVoters as |rank|}}
      <ul>
        {{#if (eq rank.rank "Abstain")}}
          <span class="rank">{{dIcon "ban"}}</span>
        {{else}}
          <span class="rank">{{rank.rank}}</span>
        {{/if}}
        {{#each rank.voters as |voter|}}
          <li>
            <a
              data-user-card={{voter.user.username}}
              title={{voter.user.username}}
            >
              {{dBoundAvatarTemplate voter.user.avatar_template "tiny"}}
            </a>
          </li>
        {{/each}}
      </ul>
    {{/each}}
  </template>
}
