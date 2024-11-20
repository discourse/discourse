import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";
import evenRound from "discourse/plugins/poll/lib/even-round";
import PollVoters from "./poll-voters";

export default class PollResultsStandardComponent extends Component {
  orderOptions = (options) => {
    options.forEach((option) => {
      option.votes = option.votes ?? 0;
    });
    return options.sort((a, b) => {
      if (a.votes < b.votes) {
        return 1;
      } else if (a.votes === b.votes) {
        if (a.html < b.html) {
          return -1;
        } else {
          return 1;
        }
      } else {
        return -1;
      }
    });
  };

  getPercentages = (ordered, votersCount) => {
    return votersCount === 0
      ? Array(ordered.length).fill(0)
      : ordered.map((o) => (100 * o.votes) / votersCount);
  };

  roundPercentages = (percentages) => {
    return this.isMultiple
      ? percentages.map(Math.floor)
      : evenRound(percentages);
  };

  enrichOptions = (ordered, rounded) => {
    ordered.forEach((option, idx) => {
      const per = rounded[idx].toString();
      const chosen = (this.args.vote || []).includes(option.id);
      option.percentage = per;
      option.chosen = chosen;
      let voters = this.args.isPublic
        ? this.args.voters?.[option.id]?.voters ?? []
        : [];
      option.voters = [...voters];
      option.loading = this.args.isPublic
        ? this.args.voters?.[option.id]?.loading ?? false
        : false;
    });

    return ordered;
  };

  get votersCount() {
    return this.args.votersCount || 0;
  }

  get orderedOptions() {
    const ordered = this.orderOptions([...this.args.options]);

    const percentages = this.getPercentages(ordered, this.votersCount);

    const roundedPercentages = this.roundPercentages(percentages);

    return this.enrichOptions(ordered, roundedPercentages);
  }

  get isMultiple() {
    return this.args.pollType === "multiple";
  }
  <template>
    <ul class="results">
      {{#each this.orderedOptions key="voters" as |option|}}
        <li class={{if option.chosen "chosen" ""}}>
          <div class="option">
            <p>
              {{#unless @isRankedChoice}}
                {{#if @showTally}}
                  <span class="absolute">{{i18n
                      "poll.votes"
                      count=option.votes
                    }}</span>
                {{else}}
                  <span class="percentage">{{i18n
                      "number.percent"
                      count=option.percentage
                    }}</span>
                {{/if}}
              {{/unless}}
              <span class="option-text">{{htmlSafe option.html}}</span>
            </p>
            {{#unless @isRankedChoice}}
              <div class="bar-back">
                <div
                  class="bar"
                  style={{htmlSafe (concat "width:" option.percentage "%")}}
                />
              </div>
            {{/unless}}
            {{#if @isPublic}}
              <PollVoters
                @postId={{@postId}}
                @pollType={{@pollType}}
                @optionId={{option.id}}
                @pollName={{@pollName}}
                @isRankedChoice={{@isRankedChoice}}
                @totalVotes={{option.votes}}
                @voters={{option.voters}}
                @fetchVoters={{@fetchVoters}}
                @loading={{option.loading}}
              />
            {{/if}}
          </div>
        </li>
      {{/each}}
    </ul>
  </template>
}
