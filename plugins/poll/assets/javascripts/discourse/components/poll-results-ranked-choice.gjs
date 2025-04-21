import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class PollResultsRankedChoiceComponent extends Component {
  get rankedChoiceWinnerText() {
    return htmlSafe(
      i18n("poll.ranked_choice.winner", {
        count: this.args.rankedChoiceOutcome?.round_activity?.length,
        winner: this.args.rankedChoiceOutcome?.winning_candidate?.html,
      })
    );
  }

  get rankedChoiceTiedText() {
    return i18n("poll.ranked_choice.tied", {
      count: this.args.rankedChoiceOutcome?.round_activity?.length,
    });
  }

  <template>
    <h3 class="poll-results-ranked-choice-subtitle-rounds">
      {{i18n "poll.ranked_choice.title.rounds"}}
    </h3>
    <table class="poll-results-ranked-choice">
      <thead>
        <tr>
          <th>{{i18n "poll.ranked_choice.round"}}</th>
          <th>{{i18n "poll.ranked_choice.majority"}}</th>
          <th>{{i18n "poll.ranked_choice.eliminated"}}</th>
        </tr>
      </thead>
      <tbody>
        {{#if @rankedChoiceOutcome}}
          {{#each @rankedChoiceOutcome.round_activity as |round|}}
            {{#if round.majority}}
              <tr>
                <td>{{round.round}}</td>
                <td>{{htmlSafe round.majority.html}}</td>
                <td>{{i18n "poll.ranked_choice.none"}}</td>
              </tr>
            {{else}}
              <tr>
                <td>{{round.round}}</td>
                <td>{{i18n "poll.ranked_choice.none"}}</td>
                <td>
                  {{#each round.eliminated as |eliminated|}}
                    {{htmlSafe eliminated.html}}
                  {{/each}}
                </td>
              </tr>
            {{/if}}
          {{/each}}
        {{/if}}
      </tbody>
    </table>
    <h3 class="poll-results-ranked-choice-subtitle-outcome">
      {{i18n "poll.ranked_choice.title.outcome"}}
    </h3>
    {{#if @rankedChoiceOutcome}}
      {{#if @rankedChoiceOutcome.tied}}
        <span
          class="poll-results-ranked-choice-info"
        >{{this.rankedChoiceTiedText}}</span>
        <ul class="poll-results-ranked-choice-tied-candidates">
          {{#each @rankedChoiceOutcome.tied_candidates as |tied_candidate|}}
            <li class="poll-results-ranked-choice-tied-candidate">{{htmlSafe
                tied_candidate.html
              }}</li>
          {{/each}}
        </ul>
      {{else}}
        <span
          class="poll-results-ranked-choice-info"
        >{{this.rankedChoiceWinnerText}}</span>
      {{/if}}
    {{/if}}
  </template>
}
