import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PoweredByDiscourse from "discourse/components/powered-by-discourse";
import icon from "discourse/helpers/d-icon";
import EmbedMode from "discourse/lib/embed-mode";
import getURL from "discourse/lib/get-url";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export default class EmbedTopicFooter extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;

  get isEmbedMode() {
    return EmbedMode.enabled;
  }

  get showFirstReplyMessage() {
    return this.args.topic?.replyCount === 0;
  }

  get showPoweredBy() {
    return this.siteSettings.enable_powered_by_discourse;
  }

  get replyButtonLabel() {
    return this.currentUser ? "topic.reply.title" : "topic.login_reply";
  }

  @action
  async handleReply() {
    if (!this.currentUser) {
      window.open(getURL("/login"), "_blank");
      return;
    }

    const topic = this.args.topic;
    if (!topic?.details?.can_create_post) {
      return;
    }

    await this.composer.open({
      action: Composer.REPLY,
      topic,
      draftKey: topic.draft_key,
      draftSequence: topic.draft_sequence,
    });
  }

  <template>
    {{#if this.isEmbedMode}}
      <div class="embed-topic-footer">
        {{#if this.showFirstReplyMessage}}
          <div class="embed-topic-footer__first-reply">
            {{icon "comment"}}
            <span>{{i18n "embed_mode.be_first_to_reply"}}</span>
            <DButton
              @action={{this.handleReply}}
              @label={{this.replyButtonLabel}}
              class="btn-primary"
            />
          </div>
        {{/if}}
        {{#if this.showPoweredBy}}
          <div class="embed-topic-footer__powered-by">
            <PoweredByDiscourse />
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
