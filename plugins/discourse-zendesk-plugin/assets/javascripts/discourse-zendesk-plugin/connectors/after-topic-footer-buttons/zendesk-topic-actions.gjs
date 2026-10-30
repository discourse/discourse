import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class ZendeskTopicActions extends Component {
  @service a11y;
  @service currentUser;

  @tracked creating = false;
  @tracked ticket;

  get currentTicket() {
    return this.ticket?.id === this.args.topic.id
      ? this.ticket
      : this.args.topic;
  }

  get hasTicket() {
    return this.currentTicket.discourse_zendesk_plugin_has_ticket;
  }

  get showActions() {
    return (
      this.currentUser?.can_create_zendesk_ticket ||
      (this.hasTicket && this.currentUser?.can_view_zendesk_ticket)
    );
  }

  get ticketUrl() {
    return this.currentTicket.discourse_zendesk_plugin_zendesk_url;
  }

  @action
  async createZendeskIssue() {
    if (this.creating) {
      return;
    }

    this.creating = true;
    try {
      this.ticket = await ajax("/zendesk-plugin/issues", {
        type: "POST",
        data: { topic_id: this.args.topic.id },
      });
      if (this.hasTicket) {
        this.a11y.announce(i18n("zendesk.ticket_created"));
      }
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
          {{#if this.hasTicket}}
            {{#if this.currentUser.can_view_zendesk_ticket}}
              <a
                class="btn-primary btn"
                href={{this.ticketUrl}}
                rel="noopener noreferrer"
                target="_blank"
              >
                {{i18n "topic.view_zendesk_issue"}}
              </a>
            {{else}}
              <span>{{i18n "zendesk.ticket_created"}}</span>
            {{/if}}
          {{else if this.currentUser.can_create_zendesk_ticket}}
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
