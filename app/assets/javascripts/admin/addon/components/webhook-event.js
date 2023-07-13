import Component from "@glimmer/component";
import { ensureJSON, plainJSON, prettyJSON } from "discourse/lib/formatter";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class WebhookEvent extends Component {
  @service dialog;

  @tracked body = "";
  @tracked bodyLabel = "";
  @tracked expandDetails = null;
  @tracked headers = "";
  expandDetailsRequestKey = "request";
  expandDetailsResponseKey = "response";

  get statusColorClasses() {
    const { status } = this.args.event;

    if (!status) {
      return "";
    }

    if (status >= 200 && status <= 299) {
      return "text-successful";
    } else {
      return "text-danger";
    }
  }

  get createdAt() {
    return moment(this.args.event.created_at).format("YYYY-MM-DD HH:mm:ss");
  }

  get completion() {
    const seconds = Math.floor(this.args.event.duration / 10.0) / 100.0;
    return I18n.t("admin.web_hooks.events.completed_in", { count: seconds });
  }

  get expandRequestIcon() {
    return this.expandDetails === this.expandDetailsRequestKey
      ? "ellipsis-h"
      : "ellipsis-v";
  }

  get expandResponseIcon() {
    return this.expandDetails === this.expandDetailsResponseKey
      ? "ellipsis-h"
      : "ellipsis-v";
  }

  @action
  redeliver() {
    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.web_hooks.events.redeliver_confirm"),
      didConfirm: async () => {
        try {
          const json = await ajax(
            `/admin/api/web_hooks/${this.args.event.web_hook_id}/events/${this.args.event.id}/redeliver`,
            { type: "POST" }
          );
          this.args.event.setProperties(json.web_hook_event);
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  toggleRequest() {
    if (this.expandDetails !== this.expandDetailsRequestKey) {
      const headers = {
        "Request URL": this.args.event.request_url,
        "Request method": "POST",
        ...ensureJSON(this.args.event.headers),
      };

      this.headers = plainJSON(headers);
      this.body = prettyJSON(this.args.event.payload);
      this.expandDetails = this.expandDetailsRequestKey;
      this.bodyLabel = I18n.t("admin.web_hooks.events.payload");
    } else {
      this.expandDetails = null;
    }
  }

  @action
  toggleResponse() {
    if (this.expandDetails !== this.expandDetailsResponseKey) {
      this.headers = plainJSON(this.args.event.response_headers);
      this.body = this.args.event.response_body;
      this.expandDetails = this.expandDetailsResponseKey;
      this.bodyLabel = I18n.t("admin.web_hooks.events.body");
    } else {
      this.expandDetails = null;
    }
  }
}
