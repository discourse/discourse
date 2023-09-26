import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import { isEmpty } from "@ember/utils";

export default class ChangeOwnerModal extends Component {
  @tracked saving = false;
  @tracked newOwner = null;
  topicController = null;
  topic = null;

  constructor() {
    super(...arguments);
    this.topicController = this.args.model.topicController;
    this.topic = this.args.model.topic;
  }
  get buttonDisabled() {
    return this.saving || isEmpty(this.newOwner);
  }

  get selectedPostsUsername() {
    return this.topicController.selectedPostsUsername;
  }

  get selectedPostIds() {
    return this.topicController.selectedPostIds;
  }

  get selectedPostsCount() {
    return this.topicController.selectedPostsCount;
  }
  @action
  async changeOwnershipOfPosts() {
    this.saving = true;

    const options = {
      post_ids: this.selectedPostIds,
      username: this.newOwner,
    };

    try {
      await Topic.changeOwners(this.topic.id, options);
      this.args.closeModal();
      this.topicController.send("deselectAll");
      if (this.topicController.multiSelect) {
        this.topicController.send("toggleMultiSelect");
      }
      DiscourseURL.routeTo(this.topic.url);
    } catch (error) {
      this.flash = I18n.t("topic.change_owner.error");
      this.saving = false;
    }

    return false;
  }

  @action
  async updateNewOwner(selected) {
    this.newOwner = selected.firstObject;
  }
}
