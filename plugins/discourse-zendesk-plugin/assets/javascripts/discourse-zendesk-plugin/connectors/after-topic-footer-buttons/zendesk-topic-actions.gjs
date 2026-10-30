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

  @service("a11y") _a11y;

  @tracked _updatedTopic;

  get #topicState() {
    return this._updatedTopic?.id === this.args.topic.id
      ? this._updatedTopic
      : this.args.topic;
  }

  get hasTicket() {
    return this.#topicState.discourse_zendesk_plugin_has_ticket;
  }

  get showActions() {
    if (
      !this.currentUser?.discourse_zendesk_plugin_status &&
      !this.currentUser?.staff
    ) {
      return false;
    }

    return (
      this.currentUser?.can_create_zendesk_ticket ||
      (this.hasTicket && this.currentUser?.can_view_zendesk_ticket)
    );
  }

  get ticketUrl() {
    return this.#topicState.discourse_zendesk_plugin_zendesk_url;
  }

  @action
  async createZendeskIssue() {
    if (this.creating) {
      return;
    }

    this.creating = true;
    try {
      this._updatedTopic = await ajax("/zendesk-plugin/issues", {
        type: "POST",
        data: { topic_id: this.args.topic.id },
      });
      if (this.hasTicket) {
        this._a11y.announce(i18n("zendesk.ticket_created"));
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
              <span class="zendesk-topic-actions__confirmation">{{i18n
                  "zendesk.ticket_created"
                }}</span>
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
