import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default class ChangeOwnerModal extends Component {
  @tracked saving = false;
  @tracked newOwner = null;
  @tracked flash;

  get buttonDisabled() {
    return this.saving || isEmpty(this.newOwner);
  }

  get selectedPostsUsername() {
    return this.args.model.selectedPostsUsername;
  }

  get selectedPostIds() {
    return this.args.model.selectedPostIds;
  }

  get selectedPostsCount() {
    return this.args.model.selectedPostsCount;
  }

  @action
  async changeOwnershipOfPosts() {
    this.saving = true;

    const options = {
      post_ids: this.selectedPostIds,
      username: this.newOwner,
    };

    try {
      await Topic.changeOwners(this.args.model.topic.id, options);
      this.args.closeModal();
      this.args.model.deselectAll();
      if (this.args.model.multiSelect) {
        this.args.model.toggleMultiSelect();
      }
      DiscourseURL.routeTo(this.args.model.topic.url);
    } catch {
      this.flash = i18n("topic.change_owner.error");
      this.saving = false;
    }

    return false;
  }

  @action
  async updateNewOwner(selected) {
    this.newOwner = selected.firstObject;
  }

  <template>
    <DModal
      @bodyClass="change-ownership"
      @closeModal={{@closeModal}}
      @title={{i18n "topic.change_owner.title"}}
      @flash={{this.flash}}
      @flashType="error"
      class="change-ownership-modal"
    >
      <:body>
        <span>
          {{htmlSafe
            (i18n
              (if
                this.selectedPostsUsername
                "topic.change_owner.instructions"
                "topic.change_owner.instructions_without_old_user"
              )
              count=this.selectedPostsCount
              old_user=this.selectedPostsUsername
            )
          }}
        </span>

        <EmailGroupUserChooser
          @value={{this.newOwner}}
          @autofocus={{true}}
          @onChange={{this.updateNewOwner}}
          @options={{hash
            maximum=1
            filterPlaceholder="topic.change_owner.placeholder"
          }}
        />
      </:body>
      <:footer>
        <DButton
          {{on "click" this.changeOwnershipOfPosts}}
          @disabled={{this.buttonDisabled}}
          @label={{if this.saving "saving" "topic.change_owner.action"}}
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
