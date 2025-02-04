import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { iconHTML } from "discourse/lib/icon-library";
import { sanitizeAsync } from "discourse/lib/text";
import Category from "discourse/models/category";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";

function customTagArray(val) {
  if (!val) {
    return [];
  }
  if (!Array.isArray(val)) {
    val = [val];
  }
  return val;
}

export default class History extends Component {
  @service dialog;
  @service site;
  @service currentUser;
  @service siteSettings;
  @service appEvents;

  @tracked loading;
  @tracked postRevision;
  @tracked viewMode = this.site.mobileView ? "inline" : "side_by_side";
  @tracked bodyDiff;
  @tracked initialLoad = true;

  constructor() {
    super(...arguments);
    this.refresh(this.args.model.postId, this.args.model.postVersion);
  }

  get loadFirstDisabled() {
    return (
      this.loading ||
      this.postRevision?.current_revision <= this.postRevision?.first_revision
    );
  }

  get loadPreviousDisabled() {
    return (
      this.loading ||
      !this.postRevision.previous_revision ||
      (!this.postRevision.previous_revision &&
        this.postRevision.current_revision <=
          this.postRevision.previous_revision)
    );
  }

  get loadNextDisabled() {
    return (
      this.loading ||
      this.postRevision?.current_revision >= this.postRevision?.next_revision
    );
  }

  get loadLastDisabled() {
    return (
      this.loading ||
      this.postRevision?.current_revision >= this.postRevision?.next_revision
    );
  }

  get displayRevisions() {
    return this.postRevision?.version_count > 2;
  }

  get modalTitleKey() {
    return this.args.model.post.version > 100
      ? "history_capped_revisions"
      : "history";
  }

  get previousVersion() {
    return this.postRevision?.current_version
      ? this.postRevision.current_version - 1
      : null;
  }

  get revisionsText() {
    return i18n(
      "post.revisions.controls.comparing_previous_to_current_out_of_total",
      {
        previous: this.previousVersion,
        icon: iconHTML("left-right"),
        current: this.postRevision?.current_version,
        total: this.postRevision?.version_count,
      }
    );
  }

  get titleDiff() {
    let mode = this.viewMode;
    if (mode === "side_by_side_markdown") {
      mode = "side_by_side";
    }
    return this.postRevision?.title_changes?.[mode];
  }

  get bodyDiffHTML() {
    return this.postRevision?.body_changes?.[this.viewMode];
  }

  @action
  async calculateBodyDiff(_, bodyDiff) {
    let html = bodyDiff;
    if (this.viewMode !== "side_by_side_markdown") {
      const opts = {
        features: { editHistory: true, historyOneboxes: true },
        allowListed: {
          editHistory: { custom: (tag, attr) => attr === "class" },
          historyOneboxes: ["header", "article", "div[style]"],
        },
      };
      html = await sanitizeAsync(html, opts);
    }
    this.bodyDiff = html;
  }

  get previousTagChanges() {
    const previousArray = customTagArray(
      this.postRevision.tags_changes.previous
    );
    const currentSet = new Set(
      customTagArray(this.postRevision.tags_changes.current)
    );

    return previousArray.map((name) => ({
      name,
      deleted: !currentSet.has(name),
    }));
  }

  get currentTagChanges() {
    const previousSet = new Set(
      customTagArray(this.postRevision.tags_changes.previous)
    );
    const currentArray = customTagArray(this.postRevision.tags_changes.current);

    return currentArray.map((name) => ({
      name,
      inserted: !previousSet.has(name),
    }));
  }

  get createdAtDate() {
    return moment(this.postRevision.created_at).format("LLLL");
  }

  get displayEdit() {
    return !!(
      this.postRevision?.can_edit &&
      this.args.model.editPost &&
      this.postRevision?.last_revision === this.postRevision?.current_revision
    );
  }

  get revertToRevisionText() {
    if (this.previousVersion) {
      return i18n("post.revisions.controls.revert", {
        revision: this.previousVersion,
      });
    }
  }

  async refresh(postId, postVersion) {
    this.loading = true;
    try {
      const result = await Post.loadRevision(postId, postVersion);
      this.postRevision = result;
    } catch (error) {
      this.args.closeModal();
      this.dialog.alert(error.jqXHR.responseJSON.errors[0]);

      const postStream = this.args.model.post?.topic?.postStream;
      if (!postStream) {
        return;
      }

      postStream
        .triggerChangedPost(postId, this.args.model)
        .then(() =>
          this.appEvents.trigger("post-stream:refresh", { id: postId })
        );
    } finally {
      this.loading = false;
      this.initialLoad = false;
    }
  }

  hide(postId, postVersion) {
    Post.hideRevision(postId, postVersion).then(() =>
      this.refresh(postId, postVersion)
    );
  }

  show(postId, postVersion) {
    Post.showRevision(postId, postVersion).then(() =>
      this.refresh(postId, postVersion)
    );
  }

  async revert(post, postVersion) {
    try {
      const result = await post.revertToRevision(postVersion);
      this.refresh(post.id, postVersion);
      if (result.topic) {
        post.set("topic.slug", result.topic.slug);
        post.set("topic.title", result.topic.title);
        post.set("topic.fancy_title", result.topic.fancy_title);
      }
      if (result.category_id) {
        post.set(
          "topic.category",
          await Category.asyncFindById(result.category_id)
        );
      }
      this.args.closeModal();
    } catch (e) {
      if (e.jqXHR.responseJSON?.errors?.[0]) {
        this.dialog.alert(e.jqXHR.responseJSON.errors[0]);
      }
    }
  }

  get editButtonLabel() {
    return `post.revisions.controls.${
      this.postRevision.wiki ? "edit_wiki" : "edit_post"
    }`;
  }

  get hiddenClasses() {
    if (this.viewMode === "inline") {
      return this.postRevision?.previous_hidden ||
        this.postRevision?.current_hidden
        ? "hidden-revision-either"
        : null;
    } else {
      let result = [];
      if (this.postRevision?.previous_hidden) {
        result.push("hidden-revision-previous");
      }
      if (this.postRevision?.current_hidden) {
        result.push("hidden-revision-current");
      }
      return result.join(" ");
    }
  }

  get previousCategory() {
    if (this.postRevision?.category_id_changes?.previous) {
      let category = Category.findById(
        this.postRevision.category_id_changes.previous
      );
      return categoryBadgeHTML(category, {
        allowUncategorized: true,
        extraClasses: "diff-del",
      });
    }
  }

  get currentCategory() {
    if (this.postRevision?.category_id_changes?.current) {
      let category = Category.findById(
        this.postRevision.category_id_changes.current
      );
      return categoryBadgeHTML(category, {
        allowUncategorized: true,
        extraClasses: "diff-ins",
      });
    }
  }

  @action
  displayInline(event) {
    event?.preventDefault();
    this.viewMode = "inline";
  }

  @action
  displaySideBySide(event) {
    event?.preventDefault();
    this.viewMode = "side_by_side";
  }

  @action
  displaySideBySideMarkdown(event) {
    event?.preventDefault();
    this.viewMode = "side_by_side_markdown";
  }

  @action
  loadFirstVersion() {
    this.refresh(this.postRevision.post_id, this.postRevision.first_revision);
  }

  @action
  loadPreviousVersion() {
    this.refresh(
      this.postRevision.post_id,
      this.postRevision.previous_revision
    );
  }

  @action
  loadNextVersion() {
    this.refresh(this.postRevision.post_id, this.postRevision.next_revision);
  }

  @action
  loadLastVersion() {
    return this.refresh(
      this.postRevision.post_id,
      this.postRevision.last_revision
    );
  }

  @action
  hideVersion() {
    this.hide(this.postRevision.post_id, this.postRevision.current_revision);
  }

  @action
  permanentlyDeleteVersions() {
    this.dialog.yesNoConfirm({
      message: i18n("post.revisions.controls.destroy_confirm"),
      didConfirm: () => {
        Post.permanentlyDeleteRevisions(this.postRevision.post_id).then(() => {
          this.args.closeModal();
        });
      },
    });
  }

  @action
  showVersion() {
    this.show(this.postRevision.post_id, this.postRevision.current_revision);
  }

  @action
  editPost() {
    this.args.model.editPost(this.args.model.post);
    this.args.closeModal();
  }

  @action
  revertToVersion() {
    this.revert(this.args.model.post, this.postRevision.current_revision);
  }
}
