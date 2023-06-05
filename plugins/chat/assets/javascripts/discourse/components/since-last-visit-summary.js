import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";

export default class SinceLastVisitSummary extends Component {
  @tracked loading = false;
  @tracked summary = null;

  @action
  summarize() {
    schedule("afterRender", () => {
      this.loading = true;

      ajax(
        `/chat/api/channels/${this.args.channelId}/summaries/last-visit?message_id=${this.args.messageId}`
      )
        .then((data) => {
          this.summary = data.summary;
        })
        .catch(popupAjaxError)
        .finally(() => (this.loading = false));
    });
  }
}
