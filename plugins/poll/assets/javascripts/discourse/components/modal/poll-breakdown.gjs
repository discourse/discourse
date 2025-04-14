import Component from "@ember/component";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classify } from "@ember/string";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import PollBreakdownChart from "discourse/plugins/poll/discourse/components/poll-breakdown-chart";
import PollBreakdownOption from "discourse/plugins/poll/discourse/components/poll-breakdown-option";

export default class PollBreakdownModal extends Component {
  @service dialog;
  @service siteSettings;

  model = null;
  charts = null;
  groupedBy = null;
  highlightedOption = null;
  displayMode = "percentage";

  init() {
    this.set("groupedBy", this.groupableUserFields[0]?.id);
    loadScript("/javascripts/Chart.min.js")
      .then(() => loadScript("/javascripts/chartjs-plugin-datalabels.min.js"))
      .then(() => {
        this.fetchGroupedPollData();
      });
    super.init(...arguments);
  }

  @discourseComputed("model.poll.title", "model.post.topic.title")
  title(pollTitle, topicTitle) {
    return pollTitle ? htmlSafe(pollTitle) : topicTitle;
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

  @discourseComputed("model.poll.options")
  totalVotes(options) {
    return options.reduce((sum, option) => sum + option.votes, 0);
  }

  fetchGroupedPollData() {
    return ajax("/polls/grouped_poll_results.json", {
      data: {
        post_id: this.model.post.id,
        poll_name: this.model.poll.name,
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
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("charts", result.grouped_results);
      });
  }

  @action
  setGrouping(value) {
    this.set("groupedBy", value);
    this.fetchGroupedPollData();
  }

  @action
  onSelectPanel(panel) {
    this.set("displayMode", panel.id);
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <DModal
      @title={{i18n "poll.breakdown.title"}}
      @closeModal={{@closeModal}}
      class="poll-breakdown has-tabs"
    >
      <:headerBelowTitle>
        <ul class="modal-tabs">
          <li
            class={{concatClass
              "modal-tab percentage"
              (if (eq this.displayMode "percentage") "is-active")
            }}
            {{on "click" (fn (mut this.displayMode) "percentage")}}
          >{{i18n "poll.breakdown.percentage"}}</li>
          <li
            class={{concatClass
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
              count=this.model.poll.voters
            }}</div>

          <ul class="poll-breakdown-options">
            {{#each this.model.poll.options as |option index|}}
              <PollBreakdownOption
                @option={{option}}
                @index={{index}}
                @totalVotes={{this.totalVotes}}
                @optionsCount={{this.model.poll.options.length}}
                @displayMode={{this.displayMode}}
                @highlightedOption={{this.highlightedOption}}
                @onMouseOver={{fn (mut this.highlightedOption) index}}
                @onMouseOut={{fn (mut this.highlightedOption) null}}
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
              @content={{this.groupableUserFields}}
              @value={{this.groupedBy}}
              @nameProperty="label"
              @onChange={{this.setGrouping}}
              class="poll-breakdown-dropdown"
            />
          </div>

          <div class="poll-breakdown-charts">
            {{#each this.charts as |chart|}}
              <PollBreakdownChart
                @group={{get chart "group"}}
                @options={{get chart "options"}}
                @displayMode={{this.displayMode}}
                @highlightedOption={{this.highlightedOption}}
                @setHighlightedOption={{fn (mut this.highlightedOption)}}
              />
            {{/each}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
