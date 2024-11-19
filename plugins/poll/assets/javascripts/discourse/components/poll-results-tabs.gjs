import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import PollResultsRankedChoice from "./poll-results-ranked-choice";
import PollResultsStandard from "./poll-results-standard";

export default class TabsComponent extends Component {
  @tracked activeTab;
  tabOne = i18n("poll.results.tabs.votes");
  tabTwo = i18n("poll.results.tabs.outcome");

  constructor() {
    super(...arguments);
    this.activeTab =
      this.args.isRankedChoice && this.args.isPublic
        ? this.tabs[1]
        : this.tabs[0];
  }
  get tabs() {
    let tabs = [];

    if (
      !this.args.isRankedChoice ||
      (this.args.isRankedChoice && this.args.isPublic)
    ) {
      tabs.push(this.tabOne);
    }

    if (this.args.isRankedChoice) {
      tabs.push(this.tabTwo);
    }
    return tabs;
  }

  @action
  selectTab(tab) {
    this.activeTab = tab;
  }

  <template>
    <div class="tab-container">
      <ul class="tabs nav nav-items">
        {{#each this.tabs as |tab|}}
          <li class="tab nav-item {{if (eq tab this.activeTab) 'active'}}">
            <DButton class="nav-btn" @action={{fn this.selectTab tab}}>
              {{tab}}
            </DButton>
          </li>
        {{/each}}
      </ul>
      <div class="tab-content">
        {{#if (eq this.activeTab this.tabOne)}}
          <PollResultsStandard
            @options={{@options}}
            @pollName={{@pollName}}
            @pollType={{@pollType}}
            @isPublic={{@isPublic}}
            @isRankedChoice={{@isRankedChoice}}
            @postId={{@postId}}
            @vote={{@vote}}
            @voters={{@voters}}
            @votersCount={{@votersCount}}
            @fetchVoters={{@fetchVoters}}
            @showTally={{@showTally}}
          />
        {{/if}}

        {{#if (eq this.activeTab this.tabTwo)}}
          <PollResultsRankedChoice
            @rankedChoiceOutcome={{@rankedChoiceOutcome}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
