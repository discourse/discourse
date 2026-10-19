import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class ZendeskTopicActions extends Component {
  @service currentUser;

  @tracked dirty;
  @tracked zendesk_id;
  @tracked zendesk_url;

  constructor() {
    super(...arguments);
    const zendesk_id = this.args.topic.get(
      "discourse_zendesk_plugin_zendesk_id"
    );
    if (zendesk_id && zendesk_id !== "") {
      this.zendesk_id = zendesk_id;
    }
    this.zendesk_url = this.args.topic.get(
      "discourse_zendesk_plugin_zendesk_url"
    );
  }

  get valid_zendesk_credential() {
    return this.currentUser?.discourse_zendesk_plugin_status;
  }

  @action
  createZendeskIssue() {
    this.dirty = true;
    ajax("/zendesk-plugin/issues", {
      type: "POST",
      data: {
        topic_id: this.args.topic.get("id"),
      },
    }).then((topic) => {
      this.zendesk_id = topic.discourse_zendesk_plugin_zendesk_id;
      this.zendesk_url = topic.discourse_zendesk_plugin_zendesk_url;
    });
  }

  <template>
    <span
      class="after-topic-footer-buttons-outlet zendesk-topic-actions"
      ...attributes
    >
      {{#if this.currentUser.staff}}
        {{#if this.valid_zendesk_credential}}
          {{#if this.zendesk_id}}
            <a
              class="btn-primary btn"
              href={{this.zendesk_url}}
              rel="noopener noreferrer"
              target="_blank"
            >
              <i class="fa fa-clone"></i>
              {{i18n "topic.view_zendesk_issue"}}
            </a>
          {{else}}
            <DButton
              class="btn-primary"
              @action={{this.createZendeskIssue}}
              @disabled={{this.dirty}}
              @label="topic.create_zendesk_issue"
            />
          {{/if}}
        {{else}}
          <p>{{i18n "zendesk.credentials_not_setup"}}</p>
        {{/if}}
      {{/if}}
    </span>
  </template>
}
