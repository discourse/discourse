import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classify } from "@ember/string";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadScript from "discourse/lib/load-script";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

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
}
