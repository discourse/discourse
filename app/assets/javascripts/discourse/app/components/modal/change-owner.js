import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";
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
}
