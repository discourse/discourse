import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import decoratePollOption from "../modifiers/decorate-poll-option";

export default class PollVotedChoicesComponent extends Component {
  get chosenOptions() {
    const { options, votes, isRankedChoice } = this.args;

    if (isRankedChoice) {
      const ranks = new Map(
        votes
          .filter((vote) => vote.rank > 0)
          .map((vote) => [vote.digest, vote.rank])
      );

      return options
        .filter((option) => ranks.has(option.id))
        .map((option) => ({ option, rank: ranks.get(option.id) }))
        .sort((a, b) => a.rank - b.rank);
    }

    return options
      .filter((option) => votes.includes(option.id))
      .map((option) => ({ option }));
  }

  <template>
    <div class="poll-voted-choices">
      <span class="poll-voted-choices__title">
        {{i18n "poll.voted_choices.title"}}
      </span>
      <ul class="poll-voted-choices__list">
        {{#each this.chosenOptions as |choice|}}
          <li class="poll-voted-choices__choice">
            {{#if @isRankedChoice}}
              <span class="poll-voted-choices__rank">{{choice.rank}}</span>
            {{else}}
              {{dIcon "check"}}
            {{/if}}
            <span
              class="option-text"
              {{decoratePollOption choice.option.html}}
            ></span>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
