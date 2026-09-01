import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

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
      class="change-ownership-modal"
      @bodyClass="change-ownership"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @title={{i18n "topic.change_owner.title"}}
    >
      <:body>
        <span>
          {{trustHTML
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
          @autofocus={{true}}
          @onChange={{this.updateNewOwner}}
          @options={{hash
            maximum=1
            filterPlaceholder="topic.change_owner.placeholder"
            filterIcon="magnifying-glass"
            useHeaderFilter=true
          }}
          @value={{this.newOwner}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @disabled={{this.buttonDisabled}}
          @label={{if this.saving "saving" "topic.change_owner.action"}}
          {{on "click" this.changeOwnershipOfPosts}}
        />
      </:footer>
    </DModal>
  </template>
}
