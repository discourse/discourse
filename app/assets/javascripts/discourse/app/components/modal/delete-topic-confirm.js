import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

// Modal that displays confirmation text when user deletes a topic
// The modal will display only if the topic exceeds a certain amount of views
export default class DeleteTopicConfirm extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked deletingTopic = false;
  @tracked flash;

  @action
  async deleteTopic() {
    try {
      this.deletingTopic = true;
      await this.args.model.topic.destroy(this.currentUser);
      this.args.closeModal();
    } catch {
      this.flash = i18n("post.controls.delete_topic_error");
      this.deletingTopic = false;
    }
  }
}
