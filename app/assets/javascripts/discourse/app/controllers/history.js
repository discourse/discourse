import { alias, equal, gt, not, or } from "@ember/object/computed";
import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import { propertyGreaterThan, propertyLessThan } from "discourse/lib/computed";
import Category from "discourse/models/category";
import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Post from "discourse/models/post";
import bootbox from "bootbox";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { iconHTML } from "discourse-common/lib/icon-library";
import { sanitizeAsync } from "discourse/lib/text";

function customTagArray(val) {
  if (!val) {
    return [];
  }
  if (!Array.isArray(val)) {
    val = [val];
  }
  return val;
}

// This controller handles displaying of history
export default Controller.extend(ModalFunctionality, {
  loading: true,
  viewMode: "side_by_side",

  @on("init")
  _changeViewModeOnMobile() {
    if (this.site && this.site.mobileView) {
      this.set("viewMode", "inline");
    }
  },

  previousFeaturedLink: alias("model.featured_link_changes.previous"),
  currentFeaturedLink: alias("model.featured_link_changes.current"),

  @discourseComputed(
    "model.tags_changes.previous",
    "model.tags_changes.current"
  )
  previousTagChanges(previous, current) {
    const previousArray = customTagArray(previous);
    const currentSet = new Set(customTagArray(current));

    return previousArray.map((name) => ({
      name,
      deleted: !currentSet.has(name),
    }));
  },

  @discourseComputed(
    "model.tags_changes.previous",
    "model.tags_changes.current"
  )
  currentTagChanges(previous, current) {
    const previousSet = new Set(customTagArray(previous));
    const currentArray = customTagArray(current);

    return currentArray.map((name) => ({
      name,
      inserted: !previousSet.has(name),
    }));
  },

  @discourseComputed("post.version")
  modalTitleKey(version) {
    if (version > 100) {
      return "history_capped_revisions";
    } else {
      return "history";
    }
  },

  @discourseComputed(
    "previousVersion",
    "model.current_version",
    "model.version_count"
  )
  revisionsText(previous, current, total) {
    return I18n.t(
      "post.revisions.controls.comparing_previous_to_current_out_of_total",
      {
        previous,
        icon: iconHTML("arrows-alt-h"),
        current,
        total,
      }
    );
  },

  @discourseComputed("previousVersion")
  revertToRevisionText(revision) {
    return I18n.t("post.revisions.controls.revert", { revision });
  },

  refresh(postId, postVersion) {
    this.set("loading", true);

    Post.loadRevision(postId, postVersion).then((result) => {
      this.setProperties({ loading: false, model: result });
    });
  },

  hide(postId, postVersion) {
    Post.hideRevision(postId, postVersion).then(() =>
      this.refresh(postId, postVersion)
    );
  },

  show(postId, postVersion) {
    Post.showRevision(postId, postVersion).then(() =>
      this.refresh(postId, postVersion)
    );
  },

  revert(post, postVersion) {
    post
      .revertToRevision(postVersion)
      .then((result) => {
        this.refresh(post.get("id"), postVersion);
        if (result.topic) {
          post.set("topic.slug", result.topic.slug);
          post.set("topic.title", result.topic.title);
          post.set("topic.fancy_title", result.topic.fancy_title);
        }
        if (result.category_id) {
          post.set("topic.category", Category.findById(result.category_id));
        }
        this.send("closeModal");
      })
      .catch(function (e) {
        if (
          e.jqXHR.responseJSON &&
          e.jqXHR.responseJSON.errors &&
          e.jqXHR.responseJSON.errors[0]
        ) {
          bootbox.alert(e.jqXHR.responseJSON.errors[0]);
        }
      });
  },

  @discourseComputed("model.created_at")
  createdAtDate(createdAt) {
    return moment(createdAt).format("LLLL");
  },

  @discourseComputed("model.current_version")
  previousVersion(current) {
    return current - 1;
  },

  @discourseComputed("model.current_revision", "model.previous_revision")
  displayGoToPrevious(current, prev) {
    return prev && current > prev;
  },

  displayRevisions: gt("model.version_count", 2),
  displayGoToFirst: propertyGreaterThan(
    "model.current_revision",
    "model.first_revision"
  ),
  displayGoToNext: propertyLessThan(
    "model.current_revision",
    "model.next_revision"
  ),
  displayGoToLast: propertyLessThan(
    "model.current_revision",
    "model.next_revision"
  ),

  hideGoToFirst: not("displayGoToFirst"),
  hideGoToPrevious: not("displayGoToPrevious"),
  hideGoToNext: not("displayGoToNext"),
  hideGoToLast: not("displayGoToLast"),

  loadFirstDisabled: or("loading", "hideGoToFirst"),
  loadPreviousDisabled: or("loading", "hideGoToPrevious"),
  loadNextDisabled: or("loading", "hideGoToNext"),
  loadLastDisabled: or("loading", "hideGoToLast"),

  @discourseComputed("model.previous_hidden")
  displayShow(prevHidden) {
    return prevHidden && this.currentUser && this.currentUser.get("staff");
  },

  @discourseComputed("model.previous_hidden")
  displayHide(prevHidden) {
    return !prevHidden && this.currentUser && this.currentUser.get("staff");
  },

  @discourseComputed(
    "model.last_revision",
    "model.current_revision",
    "model.can_edit",
    "topicController"
  )
  displayEdit(lastRevision, currentRevision, canEdit, topicController) {
    return !!(canEdit && topicController && lastRevision === currentRevision);
  },

  @discourseComputed("model.wiki")
  editButtonLabel(wiki) {
    return `post.revisions.controls.${wiki ? "edit_wiki" : "edit_post"}`;
  },

  @discourseComputed()
  displayRevert() {
    return this.currentUser && this.currentUser.get("staff");
  },

  isEitherRevisionHidden: or("model.previous_hidden", "model.current_hidden"),

  @discourseComputed(
    "model.previous_hidden",
    "model.current_hidden",
    "displayingInline"
  )
  hiddenClasses(prevHidden, currentHidden, displayingInline) {
    if (displayingInline) {
      return this.isEitherRevisionHidden ? "hidden-revision-either" : null;
    } else {
      let result = [];
      if (prevHidden) {
        result.push("hidden-revision-previous");
      }
      if (currentHidden) {
        result.push("hidden-revision-current");
      }
      return result.join(" ");
    }
  },

  displayingInline: equal("viewMode", "inline"),
  displayingSideBySide: equal("viewMode", "side_by_side"),
  displayingSideBySideMarkdown: equal("viewMode", "side_by_side_markdown"),

  @discourseComputed("displayingInline")
  inlineClass(displayingInline) {
    return displayingInline ? "active" : "";
  },

  @discourseComputed("displayingSideBySide")
  sideBySideClass(displayingSideBySide) {
    return displayingSideBySide ? "active" : "";
  },

  @discourseComputed("displayingSideBySideMarkdown")
  sideBySideMarkdownClass(displayingSideBySideMarkdown) {
    return displayingSideBySideMarkdown ? "active" : "";
  },

  @discourseComputed("model.category_id_changes")
  previousCategory(changes) {
    if (changes) {
      let category = Category.findById(changes["previous"]);
      return categoryBadgeHTML(category, { allowUncategorized: true });
    }
  },

  @discourseComputed("model.category_id_changes")
  currentCategory(changes) {
    if (changes) {
      let category = Category.findById(changes["current"]);
      return categoryBadgeHTML(category, { allowUncategorized: true });
    }
  },

  @discourseComputed("model.wiki_changes")
  wikiDisabled(changes) {
    return changes && !changes["current"];
  },

  @discourseComputed("model.post_type_changes")
  postTypeDisabled(changes) {
    return (
      changes &&
      changes["current"] !== this.site.get("post_types.moderator_action")
    );
  },

  @discourseComputed("viewMode", "model.title_changes")
  titleDiff(viewMode) {
    if (viewMode === "side_by_side_markdown") {
      viewMode = "side_by_side";
    }
    return this.get("model.title_changes." + viewMode);
  },

  @observes("viewMode", "model.body_changes")
  bodyDiffChanged() {
    const viewMode = this.viewMode;
    const html = this.get(`model.body_changes.${viewMode}`);
    if (viewMode === "side_by_side_markdown") {
      this.set("bodyDiff", html);
    } else {
      const opts = {
        features: { editHistory: true, historyOneboxes: true },
        allowListed: {
          editHistory: { custom: (tag, attr) => attr === "class" },
          historyOneboxes: ["header", "article", "div[style]"],
        },
      };

      return sanitizeAsync(html, opts).then((result) =>
        this.set("bodyDiff", result)
      );
    }
  },

  actions: {
    loadFirstVersion() {
      this.refresh(this.get("model.post_id"), this.get("model.first_revision"));
    },
    loadPreviousVersion() {
      this.refresh(
        this.get("model.post_id"),
        this.get("model.previous_revision")
      );
    },
    loadNextVersion() {
      this.refresh(this.get("model.post_id"), this.get("model.next_revision"));
    },
    loadLastVersion() {
      this.refresh(this.get("model.post_id"), this.get("model.last_revision"));
    },

    hideVersion() {
      this.hide(this.get("model.post_id"), this.get("model.current_revision"));
    },
    showVersion() {
      this.show(this.get("model.post_id"), this.get("model.current_revision"));
    },

    editPost() {
      this.topicController.send("editPost", this.post);
      this.send("closeModal");
    },

    revertToVersion() {
      this.revert(this.post, this.get("model.current_revision"));
    },

    displayInline() {
      this.set("viewMode", "inline");
    },
    displaySideBySide() {
      this.set("viewMode", "side_by_side");
    },
    displaySideBySideMarkdown() {
      this.set("viewMode", "side_by_side_markdown");
    },
  },
});
