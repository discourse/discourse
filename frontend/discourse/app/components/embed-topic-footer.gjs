import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import PoweredByDiscourse from "discourse/components/powered-by-discourse";
import icon from "discourse/helpers/d-icon";
import EmbedMode from "discourse/lib/embed-mode";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class EmbedTopicFooter extends Component {
  @service appEvents;
  @service currentUser;
  @service siteSettings;

  @tracked footerButtonsVisible = false;

  trackFooterVisibility = modifier((element) => {
    const footerButtons = document.querySelector("#topic-footer-buttons");
    const targets = [footerButtons, element].filter(Boolean);

    if (targets.length === 0) {
      return;
    }

    const visibilityMap = new Map();
    targets.forEach((t) => visibilityMap.set(t, false));

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          visibilityMap.set(entry.target, entry.isIntersecting);
        });
        this.footerButtonsVisible = [...visibilityMap.values()].some(Boolean);
      },
      { threshold: 0 }
    );

    targets.forEach((t) => observer.observe(t));

    return () => observer.disconnect();
  });

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

  get showFloatingTimelineButton() {
    if (this.currentUser) {
      return false;
    }
    return this.args.topic?.replyCount > 0 && !this.footerButtonsVisible;
  }

  @action
  handleTimelineToggle() {
    this.appEvents.trigger("topic:toggle-progress-expansion");
  }

  @action
  handleReply() {
    if (!this.currentUser) {
      window.open(getURL("/login"), "_blank");
      return;
    }

    const topic = this.args.topic;
    if (!topic?.details?.can_create_post) {
      return;
    }

    this.appEvents.trigger("embed-composer:reply-to-post", null);
  }

  <template>
    {{#if this.isEmbedMode}}
      <div class="embed-topic-footer" {{this.trackFooterVisibility}}>
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
      {{#if this.showFloatingTimelineButton}}
        <div class="embed-floating-buttons">
          <DButton
            @action={{this.handleTimelineToggle}}
            @icon="bars-staggered"
            @title="topic.progress.title"
            class="btn-default embed-floating-timeline-button"
          />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
