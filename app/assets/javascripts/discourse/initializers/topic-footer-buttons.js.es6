import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";

export default {
  name: "topic-footer-buttons",

  initialize() {
    registerTopicFooterButton({
      id: "share",
      icon: "link",
      priority: 999,
      label: "topic.share.title",
      title: "topic.share.help",
      action() {
        this.appEvents.trigger(
          "share:url",
          this.get("topic.shareUrl"),
          $("#topic-footer-buttons")
        );
      },
      dropdown() {
        return this.site.mobileView;
      },
      classNames: ["share"],
      dependentKeys: ["topic.shareUrl", "topic.isPrivateMessage"],
      displayed() {
        return !this.get("topic.isPrivateMessage");
      }
    });

    registerTopicFooterButton({
      id: "flag",
      icon: "flag",
      priority: 998,
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
      id: "invite",
      icon: "users",
      priority: 997,
      label: "topic.invite_reply.title",
      title: "topic.invite_reply.help",
      action: "showInvite",
      dropdown() {
        return this.site.mobileView;
      },
      classNames: ["invite-topic"],
      dependentKeys: ["canInviteTo", "inviteDisabled"],
      displayed() {
        return this.get("canInviteTo");
      },
      disabled() {
        return this.get("inviteDisabled");
      }
    });

    registerTopicFooterButton({
      dependentKeys: ["topic.bookmarked", "topic.isPrivateMessage"],
      id: "bookmark",
      icon: "bookmark",
      priority: 1000,
      classNames() {
        const bookmarked = this.get("topic.bookmarked");
        return bookmarked ? ["bookmark", "bookmarked"] : ["bookmark"];
      },
      label() {
        const bookmarked = this.get("topic.bookmarked");
        return bookmarked ? "bookmarked.clear_bookmarks" : "bookmarked.title";
      },
      title() {
        const bookmarked = this.get("topic.bookmarked");
        return bookmarked
          ? "bookmarked.help.unbookmark"
          : "bookmarked.help.bookmark";
      },
      action: "toggleBookmark",
      dropdown() {
        return this.site.mobileView;
      },
      displayed() {
        return !this.get("topic.isPrivateMessage");
      }
    });

    registerTopicFooterButton({
      id: "archive",
      priority: 996,
      icon() {
        return this.get("archiveIcon");
      },
      label() {
        return this.get("archiveLabel");
      },
      title() {
        return this.get("archiveTitle");
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
      displayed() {
        return this.get("canArchive");
      }
    });

    registerTopicFooterButton({
      id: "edit-message",
      priority: 750,
      icon: "pencil-alt",
      label: "topic.edit_message.title",
      title: "topic.edit_message.help",
      action: "editFirstPost",
      classNames: ["edit-message"],
      dependentKeys: ["editFirstPost", "showEditOnFooter"],
      displayed() {
        return this.get("showEditOnFooter");
      }
    });
  }
};
