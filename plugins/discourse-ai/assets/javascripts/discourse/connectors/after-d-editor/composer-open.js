import Component from "@glimmer/component";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class extends Component {
  @service currentUser;
  @service siteSettings;

  get composerModel() {
    return this.args?.outletArgs?.composer;
  }

  get renderChatWarning() {
    return this.siteSettings.ai_bot_enable_chat_warning;
  }

  @computed("composerModel.targetRecipients", "composerModel.title")
  get aiBotClasses() {
    if (
      this.composerModel?.title ===
      i18n("discourse_ai.ai_bot.default_pm_prefix")
    ) {
      return "ai-bot-chat";
    } else {
      return "ai-bot-pm";
    }
  }

  @computed("composerModel.targetRecipients")
  get isAiBotChat() {
    if (
      this.composerModel &&
      this.composerModel.targetRecipients &&
      this.currentUser.ai_enabled_chat_bots
    ) {
      let recipients = this.composerModel.targetRecipients.split(",");

      return this.currentUser.ai_enabled_chat_bots.any((bot) =>
        recipients.any((username) => username === bot.username)
      );
    }
    return false;
  }
}
