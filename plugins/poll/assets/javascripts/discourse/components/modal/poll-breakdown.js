import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { classify } from "@ember/string";
import { htmlSafe } from "@ember/template";
import loadScript from "discourse/lib/load-script";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class PollBreakdownModal extends Component {
  @service dialog;

  @tracked groupedBy = this.args.model.groupableUserFields[0];
  @tracked displayMode = "percentage";
  @tracked charts;
  @tracked highlightedOption;

  constructor() {
    super(...arguments);
    this.loadExtraJs();
  }

  async loadExtraJs() {
    await loadScript("/javascripts/Chart.min.js");
    await loadScript("/javascripts/chartjs-plugin-datalabels.min.js");
    this.fetchGroupedPollData();
  }

  get title() {
    const pollTitle = this.args.model.poll.title;
    return pollTitle ? htmlSafe(pollTitle) : this.args.model.post.topic.title;
  }

  get groupableUserFields() {
    return this.args.model.groupableUserFields.map((field) => {
      const transformed = field.split("_").filter(Boolean);

      if (transformed.length > 1) {
        transformed[0] = classify(transformed[0]);
      }

      return { id: field, label: transformed.join(" ") };
    });
  }

  get totalVotes() {
    return this.args.model.poll.options.reduce(
      (sum, option) => sum + option.votes,
      0
    );
  }

  async fetchGroupedPollData() {
    try {
      const result = await ajax("/polls/grouped_poll_results.json", {
        data: {
          post_id: this.args.model.post.id,
          poll_name: this.args.model.poll.name,
          user_field_name: this.groupedBy,
        },
      });

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.charts = result.grouped_results;
    } catch (error) {
      if (error) {
        popupAjaxError(error);
      } else {
        this.dialog.alert(I18n.t("poll.error_while_fetching_voters"));
      }
    }
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
}
