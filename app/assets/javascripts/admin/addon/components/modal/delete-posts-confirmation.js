import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";

export default class DeletePostsConfirmation extends Component {
  @tracked value;

  get text() {
    return i18n("admin.user.delete_posts.confirmation.text", {
      username: this.args.model.user.username,
      post_count: this.args.model.user.post_count,
    });
  }

  get deleteDisabled() {
    return !this.value || this.text !== this.value;
  }
}
