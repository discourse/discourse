import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import I18n from "discourse-i18n";
import DButton from "discourse/components/d-button";
import PollResultsIrv from "./poll-results-irv";
import PollResultsStandard from "./poll-results-standard";

export default class TabsComponent extends Component {
  @tracked activeTab;

  constructor() {
    super(...arguments);
    this.tabOne = I18n.t("poll.results.tabs.votes");
    this.tabTwo = I18n.t("poll.results.tabs.outcome");
    this.activeTab =
      this.args.isIrv && this.args.isPublic ? this.tabs[1] : this.tabs[0];
  }
  get tabs() {
    let tabs = [];

    if (!this.args.isIrv || (this.args.isIrv && this.args.isPublic)) {
      tabs.push(this.tabOne);
    }

    if (this.args.isIrv) {
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
            <DButton {{on "click" (fn this.selectTab tab)}}>
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
            @isIrv={{@isIrv}}
            @postId={{@postId}}
            @vote={{@vote}}
            @voters={{@voters}}
            @votersCount={{@votersCount}}
            @fetchVoters={{@fetchVoters}}
          />
        {{/if}}

        {{#if (eq this.activeTab this.tabTwo)}}
          <PollResultsIrv @irvOutcome={{@irvOutcome}} />
        {{/if}}
      </div>
    </div>
  </template>
}
