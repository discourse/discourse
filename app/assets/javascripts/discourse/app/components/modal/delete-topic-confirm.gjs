import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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

  <template>
    <DModal
      @title={{i18n "topic.actions.delete"}}
      @closeModal={{@closeModal}}
      class="delete-topic-confirm-modal"
      @flash={{this.flash}}
    >
      <:body>
        <p>
          {{i18n
            "post.controls.delete_topic_confirm_modal"
            count=this.siteSettings.min_topic_views_for_delete_confirm
          }}
        </p>
      </:body>
      <:footer>
        <DButton
          @action={{this.deleteTopic}}
          @disabled={{this.deletingTopic}}
          @label={{if
            this.deletingTopic
            "deleting"
            "post.controls.delete_topic_confirm_modal_yes"
          }}
          class="btn-danger"
        />
        <DButton
          @action={{@closeModal}}
          @label="post.controls.delete_topic_confirm_modal_no"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
