import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default class ChatMessageSeparatorNew extends Component {
  @service siteSettings;
  @service currentUser;

  get canSummarize() {
    const customSummaryAllowedGroups =
      this.siteSettings.custom_summarization_allowed_groups
        .split("|")
        .map(parseInt);

    return (
      this.siteSettings.summarization_strategy &&
      this.currentUser &&
      this.currentUser.groups.some((g) =>
        customSummaryAllowedGroups.includes(g.id)
      )
    );
  }

  @action
  summarizeSinceLastVisit() {
    showModal("since-last-visit-summary").setProperties({
      channelId: this.args.message.channel.id,
      messageId: this.args.message.id,
    });
  }
}
