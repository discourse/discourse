import { action } from "@ember/object";
import { service } from "@ember/service";
import OnboardingStep from "discourse/components/admin-onboarding/step";
import { i18n } from "discourse-i18n";

// Stands in for the posting step when a chat channel is the homepage, so the
// checklist is ticked by the first message rather than the first topic
export default class StartChattingStep extends OnboardingStep {
  static name = "start_posting";

  @service chat;
  @service("chat-channel-composer") composer;

  i18nKey = "chat.admin_onboarding.";

  constructor() {
    super(...arguments);
    this.appEvents.on("chat:message-sent", this, this.markAsCompleted);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("chat:message-sent", this, this.markAsCompleted);
  }

  get description() {
    return i18n(`${this.i18nKey}${this.name}.description`, {
      channel: this.chat.activeChannel?.title,
    });
  }

  @action
  performAction() {
    this.composer.focus({ ensureAtEnd: true, refreshHeight: true });
  }
}
