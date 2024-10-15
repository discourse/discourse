import ShareTopicModal from "discourse/components/modal/share-topic";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";

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
          this.get("topic.details.can_flag_topic") &&
          !this.get("topic.isPrivateMessage")
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
        return null;
      },
      translatedTitle() {
        return null;
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
