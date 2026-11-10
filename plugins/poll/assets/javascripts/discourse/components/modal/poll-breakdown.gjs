import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classify } from "@ember/string";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import PollBreakdownChart from "discourse/plugins/poll/discourse/components/poll-breakdown-chart";
import PollBreakdownOption from "discourse/plugins/poll/discourse/components/poll-breakdown-option";

export default class PollBreakdownModal extends Component {
  @service dialog;
  @service siteSettings;

  @tracked charts = null;
  @tracked groupedBy = null;
  @tracked highlightedOption = null;
  @tracked displayMode = "percentage";

  constructor() {
    super(...arguments);
    this.groupedBy = this.groupableUserFields[0]?.id;
    this.fetchGroupedPollData();
  }

  get title() {
    return this.args.model?.poll?.title
      ? trustHTML(this.args.model?.poll?.title)
      : this.args.model?.post?.topic?.title;
  }

  get groupableUserFields() {
    return this.siteSettings.poll_groupable_user_fields
      .split("|")
      .filter(Boolean)
      .map((field) => {
        const transformed = field.split("_").filter(Boolean);

        if (transformed.length > 1) {
          transformed[0] = classify(transformed[0]);
        }

        return { id: field, label: transformed.join(" ") };
      });
  }

  get totalVotes() {
    return this.args.model?.poll?.options?.reduce(
      (sum, option) => sum + option.votes,
      0
    );
  }

  fetchGroupedPollData() {
    return ajax("/polls/grouped_poll_results.json", {
      data: {
        post_id: this.args.model.post.id,
        poll_name: this.args.model.poll.name,
        user_field_name: this.groupedBy,
      },
    })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(i18n("poll.error_while_fetching_voters"));
        }
      })
      .then((result) => {
        if (this.isDestroying) {
          return;
        }

        this.charts = result.grouped_results;
      });
  }

  @action
  setGrouping(value) {
    this.groupedBy = value;
    this.fetchGroupedPollData();
  }

  @action
  onSelectPanel(panel) {
    this.displayMode = panel.id;
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <DModal
      class="poll-breakdown has-tabs"
      @closeModal={{@closeModal}}
      @title={{i18n "poll.breakdown.title"}}
    >
      <:headerBelowTitle>
        <ul class="modal-tabs">
          <li
            class={{dConcatClass
              "modal-tab percentage"
              (if (eq this.displayMode "percentage") "is-active")
            }}
            {{on "click" (fn (mut this.displayMode) "percentage")}}
          >{{i18n "poll.breakdown.percentage"}}</li>
          <li
            class={{dConcatClass
              "modal-tab count"
              (if (eq this.displayMode "count") "is-active")
            }}
            {{on "click" (fn (mut this.displayMode) "count")}}
          >{{i18n "poll.breakdown.count"}}</li>
        </ul>
      </:headerBelowTitle>
      <:body>
        <div class="poll-breakdown-sidebar">
          <p class="poll-breakdown-title">
            {{this.title}}
          </p>

          <div class="poll-breakdown-total-votes">{{i18n
              "poll.breakdown.votes"
              count=@model.poll.voters
            }}</div>

          <ul class="poll-breakdown-options">
            {{#each @model.poll.options as |option index|}}
              <PollBreakdownOption
                @displayMode={{this.displayMode}}
                @highlightedOption={{this.highlightedOption}}
                @index={{index}}
                @onMouseOut={{fn (mut this.highlightedOption) null}}
                @onMouseOver={{fn (mut this.highlightedOption) index}}
                @option={{option}}
                @optionsCount={{@model.poll.options.length}}
                @totalVotes={{this.totalVotes}}
              />
            {{/each}}
          </ul>
        </div>

        <div class="poll-breakdown-body">
          <div class="poll-breakdown-body-header">
            <label class="poll-breakdown-body-header-label">{{i18n
                "poll.breakdown.breakdown"
              }}</label>

            <ComboBox
              class="poll-breakdown-dropdown"
              @content={{this.groupableUserFields}}
              @nameProperty="label"
              @onChange={{this.setGrouping}}
              @value={{this.groupedBy}}
            />
          </div>

          <div class="poll-breakdown-charts">
            {{#each this.charts as |chart|}}
              <PollBreakdownChart
                @displayMode={{this.displayMode}}
                @group={{get chart "group"}}
                @highlightedOption={{this.highlightedOption}}
                @options={{get chart "options"}}
                @setHighlightedOption={{fn (mut this.highlightedOption)}}
              />
            {{/each}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
