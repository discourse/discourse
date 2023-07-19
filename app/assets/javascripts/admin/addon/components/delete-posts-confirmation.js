import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import I18n from "I18n";

export default class DeletePostsConfirmation extends Component {
  @controller adminUserIndex;

  @tracked value;

  get text() {
    return I18n.t("admin.user.delete_posts.confirmation.text", {
      username: this.args.model.username,
      post_count: this.args.model.post_count,
    });
  }

  get title() {
    return I18n.t("admin.user.delete_posts.confirmation.title", {
      username: this.args.model.username,
    });
  }

  get description() {
    return I18n.t("admin.user.delete_posts.confirmation.description", {
      username: this.args.model.username,
      post_count: this.args.model.post_count,
      text: this.text,
    });
  }

  get deleteButtonText() {
    return I18n.t("admin.user.delete_posts.confirmation.delete", {
      username: this.args.model.username,
    });
  }

  get deleteDisabled() {
    return !this.value || this.text !== this.value;
  }

  @action
  confirm() {
    this.adminUserIndex.send("deleteAllPosts");
  }
}
