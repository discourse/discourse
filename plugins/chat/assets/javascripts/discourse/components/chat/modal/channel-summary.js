import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default class ChatModalChannelSummary extends Component {
  @service chatApi;

  @tracked sinceHours = null;
  @tracked loading = false;
  @tracked summary = null;

  availableSummaries = {};

  sinceOptions = [1, 3, 6, 12, 24, 72, 168].map((hours) => {
    return {
      name: I18n.t("chat.summarization.since", { count: hours }),
      value: hours,
    };
  });

  get channelId() {
    return this.args.model.channelId;
  }

  @action
  summarize(since) {
    this.sinceHours = since;
    this.loading = true;

    if (this.availableSummaries[since]) {
      this.summary = this.availableSummaries[since];
      this.loading = false;
      return;
    }

    return this.chatApi
      .summarize(this.channelId, { since })
      .then((data) => {
        this.availableSummaries[this.sinceHours] = data.summary;
        this.summary = this.availableSummaries[this.sinceHours];
      })
      .catch(popupAjaxError)
      .finally(() => (this.loading = false));
  }
}
