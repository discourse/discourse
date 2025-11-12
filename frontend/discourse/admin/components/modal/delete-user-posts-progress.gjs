import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import AdminUser from "discourse/admin/models/admin-user";
import DModal from "discourse/components/d-modal";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class DeleteUserPostsProgress extends Component {
  @tracked deletedPosts = 0;
  @tracked flash;

  constructor() {
    super(...arguments);
    this.deletePosts();
  }

  get userPostCount() {
    return this.args.model.user.get("post_count");
  }

  get deletedPercentage() {
    return Math.floor((this.deletedPosts * 100) / this.userPostCount);
  }

  @action
  async deletePosts() {
    try {
      const progress = await this.args.model.user.deleteAllPosts();
      this.deletedPosts = progress.posts_deleted;
      this.args.model.updateUserPostCount(
        this.userPostCount - this.deletedPosts
      );
      // continue deleting posts if more remain, otherwise exit
      this.userPostCount > 0 ? this.deletePosts() : this.args.closeModal();
    } catch (e) {
      AdminUser.find(this.args.model.user.id).then((u) =>
        this.args.model.user.setProperties(u)
      );
      this.flash = extractError(e, i18n("admin.user.delete_posts_failed"));
    }
  }

  <template>
    <DModal
      @title={{i18n "admin.user.delete_posts.progress.title"}}
      @closeModal={{@closeModal}}
      class="admin-delete-user-posts-progress-modal"
      @flash={{this.flash}}
      @dismissable={{false}}
    >
      <:body>
        <p>{{i18n "admin.user.delete_posts.progress.description"}}</p>
        <div class="progress-bar">
          <span
            style={{htmlSafe (concat "width: " this.deletedPercentage "%")}}
          />
        </div>
      </:body>
    </DModal>
  </template>
}
