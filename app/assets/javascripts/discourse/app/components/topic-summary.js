import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";

export default class TopicSummary extends Component {
  @tracked loading = false;
  @tracked summary = null;

  @action
  summarize() {
    schedule("afterRender", () => {
      this.loading = true;

      ajax(`/t/${this.args.topicId}/strategy-summary`)
        .then((data) => {
          this.summary = data.summary;
        })
        .catch(popupAjaxError)
        .finally(() => (this.loading = false));
    });
  }
}
