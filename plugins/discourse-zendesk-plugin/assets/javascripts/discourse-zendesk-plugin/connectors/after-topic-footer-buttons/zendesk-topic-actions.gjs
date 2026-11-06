import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class ZendeskTopicActions extends Component {
  @service currentUser;

  @tracked creating = false;

  @service("toasts") _toasts;

  get showActions() {
    if (
      !this.currentUser?.discourse_zendesk_plugin_status &&
      !this.currentUser?.staff
    ) {
      return false;
    }

    return this.args.topic.get("discourse_zendesk_plugin_has_ticket")
      ? this.currentUser?.can_view_zendesk_ticket
      : this.currentUser?.can_create_zendesk_ticket;
  }

  @action
  async createZendeskIssue() {
    if (this.creating) {
      return;
    }

    const topic = this.args.topic;
    this.creating = true;
    try {
      const updatedTopic = await ajax("/zendesk-plugin/issues", {
        type: "POST",
        data: { topic_id: topic.id },
      });
      topic.setProperties({
        discourse_zendesk_plugin_has_ticket:
          updatedTopic.discourse_zendesk_plugin_has_ticket,
        discourse_zendesk_plugin_zendesk_url:
          updatedTopic.discourse_zendesk_plugin_zendesk_url,
      });
      this._toasts.success({
        data: { message: i18n("zendesk.ticket_created") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.creating = false;
    }
  }

  <template>
    {{#if this.showActions}}
      <span
        class="after-topic-footer-buttons-outlet zendesk-topic-actions"
        ...attributes
      >
        {{#if this.currentUser.discourse_zendesk_plugin_status}}
          {{#if @topic.discourse_zendesk_plugin_has_ticket}}
            <a
              class="btn-primary btn"
              href={{@topic.discourse_zendesk_plugin_zendesk_url}}
              rel="noopener noreferrer"
              target="_blank"
            >
              {{i18n "topic.view_zendesk_issue"}}
            </a>
          {{else}}
            <DButton
              class="btn-primary"
              @action={{this.createZendeskIssue}}
              @disabled={{this.creating}}
              @label="topic.create_zendesk_issue"
            />
          {{/if}}
        {{else}}
          <p>{{i18n "zendesk.credentials_not_setup"}}</p>
        {{/if}}
      </span>
    {{/if}}
  </template>
}
