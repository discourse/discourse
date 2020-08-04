import I18n from "I18n";
import showModal from "discourse/lib/show-modal";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import { formattedReminderTime } from "discourse/lib/bookmark";

const SHARE_PRIORITY = 1000;
const BOOKMARK_PRIORITY = 900;
const ARCHIVE_PRIORITY = 800;
const FLAG_PRIORITY = 700;
const DEFER_PRIORITY = 500;

export default {
  name: "topic-footer-buttons",

  initialize(container) {
    const currentUser = container.lookup("current-user:main");
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
        const panels = [
          {
            id: "share",
            title: "topic.share.extended_title",
            model: {
              topic: this.topic
            }
          }
        ];

        if (this.canInviteTo && !this.inviteDisabled) {
          let invitePanelTitle;

          if (this.isPM) {
            invitePanelTitle = "topic.invite_private.title";
          } else if (this.invitingToTopic) {
            invitePanelTitle = "topic.invite_reply.title";
          } else {
            invitePanelTitle = "user.invited.create";
          }

          panels.push({
            id: "invite",
            title: invitePanelTitle,
            model: {
              inviteModel: this.topic
            }
          });
        }

        showModal("share-and-invite", {
          modalClass: "share-and-invite",
          panels
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
        "invitingToTopic"
      ]
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
      }
    });

    registerTopicFooterButton({
      dependentKeys: ["topic.bookmarked"],
      id: "bookmark",
      icon() {
        if (this.get("topic.bookmark_reminder_at")) {
          return "discourse-bookmark-clock";
        }
        return "bookmark";
      },
      priority: BOOKMARK_PRIORITY,
      classNames() {
        const bookmarked = this.get("topic.bookmarked");
        return bookmarked ? ["bookmark", "bookmarked"] : ["bookmark"];
      },
      label() {
        if (!this.get("topic.isPrivateMessage") || this.site.mobileView) {
          const bookmarked = this.get("topic.bookmarked");
          return bookmarked ? "bookmarked.clear_bookmarks" : "bookmarked.title";
        }
      },
      translatedTitle() {
        const bookmarked = this.get("topic.bookmarked");
        const bookmark_reminder_at = this.get("topic.bookmark_reminder_at");
        if (bookmarked) {
          if (bookmark_reminder_at) {
            return I18n.t("bookmarked.help.unbookmark_with_reminder", {
              reminder_at: formattedReminderTime(
                bookmark_reminder_at,
                currentUser.resolvedTimezone(currentUser)
              )
            });
          }
          return I18n.t("bookmarked.help.unbookmark");
        }
        return I18n.t("bookmarked.help.bookmark");
      },
      action: "toggleBookmark",
      dropdown() {
        return this.site.mobileView;
      }
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
        "toggleArchiveMessage"
      ],
      dropdown() {
        return this.site.mobileView;
      },
      displayed() {
        return this.canArchive;
      }
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
      }
    });
  }
};
