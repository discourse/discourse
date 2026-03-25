import Component from "@glimmer/component";
import { service } from "@ember/service";
import PoweredByDiscourse from "discourse/components/powered-by-discourse";
import icon from "discourse/helpers/d-icon";
import EmbedMode from "discourse/lib/embed-mode";
import { i18n } from "discourse-i18n";

export default class EmbedTopicFooter extends Component {
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

  <template>
    {{#if this.isEmbedMode}}
      <div class="embed-topic-footer">
        {{#if this.showFirstReplyMessage}}
          <div class="embed-topic-footer__first-reply">
            {{icon "comment"}}
            <span>{{i18n "embed_mode.be_first_to_reply"}}</span>
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
