/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("")
export default class ZendeskTopicActions extends Component {
  init() {
    super.init(...arguments);
    this.setProperties({
      can_create_zendesk_ticket: this.topic.get("can_create_zendesk_ticket"),
      can_view_zendesk_ticket: this.topic.get("can_view_zendesk_ticket"),
      zendesk_url: this.topic.get("discourse_zendesk_plugin_zendesk_url"),
    });
  }

  @action
  createZendeskIssue() {
    this.set("dirty", true);
    ajax("/zendesk-plugin/issues", {
      type: "POST",
      data: {
        topic_id: this.get("topic").get("id"),
      },
    }).then((topic) => {
      this.setProperties({
        can_create_zendesk_ticket: topic.can_create_zendesk_ticket,
        can_view_zendesk_ticket: topic.can_view_zendesk_ticket,
        zendesk_url: topic.discourse_zendesk_plugin_zendesk_url,
      });
    });
  }

  <template>
    {{#if this.can_view_zendesk_ticket}}
      <span
        class="after-topic-footer-buttons-outlet zendesk-topic-actions"
        ...attributes
      >
        <a
          href={{this.zendesk_url}}
          target="_blank"
          class="btn btn-primary"
          rel="noopener noreferrer"
        >
          {{dIcon "clone"}}
          {{i18n "topic.view_zendesk_issue"}}
        </a>
      </span>
    {{else if this.can_create_zendesk_ticket}}
      <span
        class="after-topic-footer-buttons-outlet zendesk-topic-actions"
        ...attributes
      >
        <DButton
          class="btn-primary"
          @action={{this.createZendeskIssue}}
          @label="topic.create_zendesk_issue"
          @disabled={{this.dirty}}
        />
      </span>
    {{/if}}
  </template>
}
