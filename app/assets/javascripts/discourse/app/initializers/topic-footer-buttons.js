import I18n from "I18n";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import showModal from "discourse/lib/show-modal";

const SHARE_PRIORITY = 1000;
const BOOKMARK_PRIORITY = 900;
const ARCHIVE_PRIORITY = 800;
const FLAG_PRIORITY = 700;
const DEFER_PRIORITY = 500;

export default {
  name: "topic-footer-buttons",

  initialize() {
    registerTopicFooterButton({
      id: "share-and-invite",
      icon: "link",
      priority: SHARE_PRIORITY,
      label() {
        if (!this.get("topic.isPrivateMessage") || this.site.mobileView) {
          return "topic.share.title";
        }
      },
      title: "topic.share.help",
      action() {
        const controller = showModal("share-topic");
        controller.setProperties({
          allowInvites: this.canInviteTo && !this.inviteDisabled,
          topic: this.topic,
        });
      },
      dropdown() {
        return this.site.mobileView;
      },
      classNames: ["share-and-invite"],
      dependentKeys: [
        "topic.shareUrl",
        "topic.isPrivateMessage",
        "canInviteTo",
        "inviteDisabled",
        "isPM",
        "invitingToTopic",
      ],
    });

    registerTopicFooterButton({
      id: "flag",
      icon: "flag",
      priority: FLAG_PRIORITY,
      label: "topic.flag_topic.title",
      title: "topic.flag_topic.help",
      action: "showFlagTopic",
      dropdown() {
        return this.site.mobileView;
      },
      classNames: ["flag-topic"],
      dependentKeys: ["topic.details.can_flag_topic", "topic.isPrivateMessage"],
      displayed() {
        return (
          this.get("topic.details.can_flag_topic") &&
          !this.get("topic.isPrivateMessage")
        );
      },
    });

    registerTopicFooterButton({
      dependentKeys: ["topic.bookmarked", "topic.bookmarksWereChanged"],
      id: "bookmark",
      icon() {
        const bookmarkedPosts = this.topic.bookmarked_posts;
        if (bookmarkedPosts && bookmarkedPosts.find((x) => x.reminder_at)) {
          return "discourse-bookmark-clock";
        }
        return "bookmark";
      },
      priority: BOOKMARK_PRIORITY,
      classNames() {
        return this.topic.bookmarked
          ? ["bookmark", "bookmarked"]
          : ["bookmark"];
      },
      label() {
        if (!this.topic.isPrivateMessage || this.site.mobileView) {
          const bookmarkedPosts = this.topic.bookmarked_posts;
          const bookmarkedPostsCount = bookmarkedPosts
            ? bookmarkedPosts.length
            : 0;

          if (bookmarkedPostsCount === 0) {
            return "bookmarked.title";
          } else if (bookmarkedPostsCount === 1) {
            return "bookmarked.edit_bookmark";
          } else {
            return "bookmarked.clear_bookmarks";
          }
        }
      },
      translatedTitle() {
        const bookmarkedPosts = this.topic.bookmarked_posts;
        if (!bookmarkedPosts || bookmarkedPosts.length === 0) {
          return I18n.t("bookmarked.help.bookmark");
        } else if (bookmarkedPosts.length === 1) {
          return I18n.t("bookmarked.help.edit_bookmark");
        } else if (bookmarkedPosts.find((x) => x.reminder_at)) {
          return I18n.t("bookmarked.help.unbookmark_with_reminder");
        } else {
          return I18n.t("bookmarked.help.unbookmark");
        }
      },
      action: "toggleBookmark",
      dropdown() {
        return this.site.mobileView;
      },
    });

    registerTopicFooterButton({
      id: "archive",
      priority: ARCHIVE_PRIORITY,
      icon() {
        return this.archiveIcon;
      },
      label() {
        return this.archiveLabel;
      },
      title() {
        return this.archiveTitle;
      },
      action: "toggleArchiveMessage",
      classNames: ["standard", "archive-topic"],
      dependentKeys: [
        "canArchive",
        "archiveIcon",
        "archiveLabel",
        "archiveTitle",
        "toggleArchiveMessage",
      ],
      dropdown() {
        return this.site.mobileView;
      },
      displayed() {
        return this.canArchive;
      },
    });

    registerTopicFooterButton({
      id: "defer",
      icon: "circle",
      priority: DEFER_PRIORITY,
      label: "topic.defer.title",
      title: "topic.defer.help",
      action: "deferTopic",
      displayed() {
        return this.canDefer;
      },
      dropdown() {
        return this.site.mobileView;
      },
    });
  },
};
