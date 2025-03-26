import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ensureJSON, plainJSON, prettyJSON } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

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
    return i18n("admin.web_hooks.events.completed_in", { count: seconds });
  }

  get expandRequestIcon() {
    return this.expandDetails === this.expandDetailsRequestKey
      ? "ellipsis"
      : "ellipsis-vertical";
  }

  get expandResponseIcon() {
    return this.expandDetails === this.expandDetailsResponseKey
      ? "ellipsis"
      : "ellipsis-vertical";
  }

  @action
  redeliver() {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.web_hooks.events.redeliver_confirm"),
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
      this.bodyLabel = i18n("admin.web_hooks.events.payload");
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
      this.bodyLabel = i18n("admin.web_hooks.events.body");
    } else {
      this.expandDetails = null;
    }
  }

  <template>
    <li>
      <div class="col first status">
        {{#if @event.redelivering}}
          {{icon "arrows-rotate"}}
        {{else}}
          <span class={{this.statusColorClasses}}>{{@event.status}}</span>
        {{/if}}
      </div>

      <div class="col event-id">{{@event.id}}</div>

      <div class="col timestamp">{{this.createdAt}}</div>

      <div class="col completion">{{this.completion}}</div>

      <div class="col actions">
        <DButton
          @icon={{this.expandRequestIcon}}
          @action={{this.toggleRequest}}
          @label="admin.web_hooks.events.request"
        />
        <DButton
          @icon={{this.expandResponseIcon}}
          @action={{this.toggleResponse}}
          @label="admin.web_hooks.events.response"
        />
        <DButton
          @icon="arrows-rotate"
          @action={{this.redeliver}}
          @label="admin.web_hooks.events.redeliver"
        />
      </div>

      {{#if this.expandDetails}}
        <div class="details">
          <h3>{{i18n "admin.web_hooks.events.headers"}}</h3>
          <pre><code>{{this.headers}}</code></pre>

          <h3>{{this.bodyLabel}}</h3>
          <pre><code>{{this.body}}</code></pre>
        </div>
      {{/if}}
    </li>
  </template>
}
