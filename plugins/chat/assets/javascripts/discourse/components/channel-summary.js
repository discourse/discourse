import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import I18n from "I18n";

export default class ChannelSumarry extends Component {
  @tracked sinceHours = null;
  @tracked loading = false;
  @tracked availableSummaries = {};
  @tracked summary = null;
  sinceOptions = [
    {
      name: I18n.t("chat.summarization.since", { count: 1 }),
      value: 1,
    },
    {
      name: I18n.t("chat.summarization.since", { count: 3 }),
      value: 3,
    },
    {
      name: I18n.t("chat.summarization.since", { count: 6 }),
      value: 6,
    },
    {
      name: I18n.t("chat.summarization.since", { count: 12 }),
      value: 12,
    },
    {
      name: I18n.t("chat.summarization.since", { count: 24 }),
      value: 24,
    },
    {
      name: I18n.t("chat.summarization.since", { count: 72 }),
      value: 72,
    },
    {
      name: I18n.t("chat.summarization.since", { count: 168 }),
      value: 168,
    },
  ];

  @action
  summarize(value) {
    this.loading = true;

    if (this.availableSummaries[value]) {
      this.summary = this.availableSummaries[value];
      this.loading = false;
      return;
    }

    ajax(`/chat/api/channels/${this.args.channelId}/summarize`, {
      method: "GET",
      data: { since: value },
    })
      .then((data) => {
        this.availableSummaries[this.sinceHours] = data.summary;
        this.summary = this.availableSummaries[this.sinceHours];
      })
      .catch(popupAjaxError)
      .finally(() => (this.loading = false));
  }
}
