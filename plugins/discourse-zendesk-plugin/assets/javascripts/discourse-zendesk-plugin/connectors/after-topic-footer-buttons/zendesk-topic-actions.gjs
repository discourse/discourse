import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames, tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

@tagName("span")
@classNames("after-topic-footer-buttons-outlet", "zendesk-topic-actions")
export default class ZendeskTopicActions extends Component {
  init() {
    super.init(...arguments);
    const zendesk_id = this.topic.get("discourse_zendesk_plugin_zendesk_id");
    if (zendesk_id && zendesk_id !== "") {
      this.set("zendesk_id", zendesk_id);
    }
    this.setProperties({
      zendesk_url: this.topic.get("discourse_zendesk_plugin_zendesk_url"),
      valid_zendesk_credential: this.get(
        "currentUser.discourse_zendesk_plugin_status"
      ),
    });
  }

  @action
  createZendeskIssue() {
    let self = this;
    self.set("dirty", true);
    ajax("/zendesk-plugin/issues", {
      type: "POST",
      data: {
        topic_id: this.get("topic").get("id"),
      },
    }).then((topic) => {
      self.setProperties({
        zendesk_id: topic.discourse_zendesk_plugin_zendesk_id,
        zendesk_url: topic.discourse_zendesk_plugin_zendesk_url,
      });
    });
  }

  <template>
    {{#if this.currentUser.staff}}
      {{#if this.valid_zendesk_credential}}
        {{#if this.zendesk_id}}
          <a
            href={{this.zendesk_url}}
            target="_blank"
            class="btn-primary btn"
            rel="noopener noreferrer"
          >
            <i class="fa fa-clone"></i>
            {{i18n "topic.view_zendesk_issue"}}
          </a>
        {{else}}
          <DButton
            class="btn-primary"
            {{! template-lint-disable no-action }}
            @action={{action "createZendeskIssue"}}
            @label="topic.create_zendesk_issue"
            @disabled={{this.dirty}}
          />
        {{/if}}
      {{else}}
        <p>{{i18n "zendesk.credentials_not_setup"}}</p>
      {{/if}}
    {{/if}}
  </template>
}
