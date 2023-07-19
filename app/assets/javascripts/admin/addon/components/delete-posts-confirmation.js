import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import I18n from "I18n";

export default class DeletePostsConfirmation extends Component {
  @tracked value;
  @controller adminUserIndex;

  get text() {
    return I18n.t(`admin.user.delete_posts.confirmation.text`, {
      username: this.args.model.username,
      postCount: this.args.model.post_count,
    });
  }

  get deleteButtonText() {
    return I18n.t(`admin.user.delete_posts.confirmation.delete`, {
      username: this.args.model.username,
    });
  }

  get deleteDisabled() {
    return !this.value || this.text !== value;
  }

  @action
  confirm() {
    this.adminUserIndex.send("deleteAllPosts");
  }
}
