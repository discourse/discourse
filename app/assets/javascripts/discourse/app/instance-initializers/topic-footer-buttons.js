import ShareTopicModal from "discourse/components/modal/share-topic";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import {
  NO_REMINDER_ICON,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";

const SHARE_PRIORITY = 1000;
const BOOKMARK_PRIORITY = 900;
const ARCHIVE_PRIORITY = 800;
const FLAG_PRIORITY = 700;
const DEFER_PRIORITY = 500;

export default {
  initialize(owner) {
    registerTopicFooterButton({
      id: "share-and-invite",
      icon: "d-topic-share",
      priority: SHARE_PRIORITY,
      label() {
        if (!this.get("topic.isPrivateMessage") || this.site.mobileView) {
          return "footer_nav.share";
        }
      },
      title: "topic.share.help",
      action() {
        owner.lookup("service:modal").show(ShareTopicModal, {
          model: {
            category: this.topic.category,
            topic: this.topic,
            allowInvites:
              this.currentUser.can_invite_to_forum &&
              this.canInviteTo &&
              !this.inviteDisabled,
          },
        });
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
          this.topic.details.can_flag_topic && !this.topic.isPrivateMessage
        );
      },
    });

    registerTopicFooterButton({
      dependentKeys: ["topic.bookmarked", "topic.bookmarksWereChanged"],
      id: "bookmark",
      priority: BOOKMARK_PRIORITY,
      action: "toggleBookmark",

      // NOTE: These are null because the BookmarkMenu component is used
      // for this button instead in the template.

      icon() {
        if (this.topic.bookmarks.some((bookmark) => bookmark.reminder_at)) {
          return WITH_REMINDER_ICON;
        }
        return NO_REMINDER_ICON;
      },
      classNames() {
        return this.topic.bookmarked
          ? ["bookmark", "bookmarked"]
          : ["bookmark"];
      },
      label() {
        if (!this.topic.isPrivateMessage || this.site.mobileView) {
          const topicBookmarkCount = this.topic.bookmarkCount;
          if (topicBookmarkCount === 0) {
            return "bookmarked.title";
          } else if (topicBookmarkCount === 1) {
            return "bookmarked.edit_bookmark";
          } else {
            return "bookmarked.clear_bookmarks";
          }
        }
      },
      translatedTitle() {
        const topicBookmarkCount = this.topic.bookmarkCount;
        if (topicBookmarkCount === 0) {
          return i18n("bookmarked.help.bookmark");
        } else if (topicBookmarkCount === 1) {
          const anyTopicBookmarks = this.topic.bookmarks.some(
            (bookmark) => bookmark.bookmarkable_type === "Topic"
          );

          if (anyTopicBookmarks) {
            return i18n("bookmarked.help.edit_bookmark_for_topic");
          } else {
            return i18n("bookmarked.help.edit_bookmark");
          }
        } else if (
          this.topic.bookmarks.some((bookmark) => bookmark.reminder_at)
        ) {
          return i18n("bookmarked.help.unbookmark_with_reminder");
        } else {
          return i18n("bookmarked.help.unbookmark");
        }
      },
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
      classNames: ["defer-topic"],
      displayed() {
        return this.canDefer;
      },
      dropdown() {
        return this.site.mobileView;
      },
    });
  },
};
