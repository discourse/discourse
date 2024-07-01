import Component from "@glimmer/component";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";

export default class PollResultsIrvComponent extends Component {
  get irvWinnerText() {
    return I18n.t("poll.irv.winner", {
      count: this.args.irvOutcome.round_activity.length,
      winner: this.args.irvOutcome.winning_candidate.html,
    });
  }

  get irvTiedText() {
    return I18n.t("poll.irv.tied", {
      count: this.args.irvOutcome.round_activity.length,
    });
  }
  <template>
    <h3 class="poll-results-irv-subtitle-rounds">
      {{i18n "poll.irv.title.rounds"}}
    </h3>
    <table class="poll-results-irv">
      <thead>
        <tr>
          <th>{{i18n "poll.irv.round"}}</th>
          <th>{{i18n "poll.irv.majority"}}</th>
          <th>{{i18n "poll.irv.eliminated"}}</th>
        </tr>
      </thead>
      <tbody>
        {{#each @irvOutcome.round_activity as |round|}}
          {{#if round.majority}}
            <tr>
              <td>{{round.round}}</td>
              <td>{{round.majority.html}}</td>
              <td>{{i18n "poll.irv.none"}}</td>
            </tr>
          {{else}}
            <tr>
              <td>{{round.round}}</td>
              <td>{{i18n "poll.irv.none"}}</td>
              <td>
                {{#each round.eliminated as |eliminated|}}
                  {{eliminated.html}}
                {{/each}}
              </td>
            </tr>
          {{/if}}
        {{/each}}
      </tbody>
    </table>
    <h3 class="poll-results-irv-subtitle-outcome">
      {{i18n "poll.irv.title.outcome"}}
    </h3>
    {{#if @irvOutcome.tied}}
      <span class="poll-results-irv-info">{{this.irvTiedText}}</span>
      <ul class="poll-results-irv-tied-candidates">
        {{#each @irvOutcome.tied_candidates as |tied_candidate|}}
          <li
            class="poll-results-irv-tied-candidate"
          >{{tied_candidate.html}}</li>
        {{/each}}
      </ul>
    {{else}}
      <span class="poll-results-irv-info">{{this.irvWinnerText}}</span>
    {{/if}}
  </template>
}
