import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["topic-footer-mobile-dropdown"],
  classNames: "topic-footer-mobile-dropdown",
  filterable: false,
  autoFilterable: false,
  allowInitialValueMutation: false,

  computeHeaderContent() {
    let content = this._super(...arguments);
    content.name = I18n.t("topic.controls");
    return content;
  },

  computeContent(content) {
    const topic = this.get("topic");
    const details = topic.get("details");

    if (details.get("can_invite_to")) {
      content.push({
        id: "invite",
        icon: "users",
        name: I18n.t("topic.invite_reply.title"),
        __sk_row_type: "noopRow"
      });
    }

    if (
      (topic.get("bookmarked") && !topic.get("bookmarking")) ||
      (!topic.get("bookmarked") && topic.get("bookmarking"))
    ) {
      content.push({
        id: "bookmark",
        icon: "bookmark",
        name: I18n.t("bookmarked.clear_bookmarks"),
        __sk_row_type: "noopRow"
      });
    } else {
      content.push({
        id: "bookmark",
        icon: "bookmark",
        name: I18n.t("bookmarked.title"),
        __sk_row_type: "noopRow"
      });
    }

    content.push({
      id: "share",
      icon: "link",
      name: I18n.t("topic.share.title"),
      __sk_row_type: "noopRow"
    });

    if (details.get("can_flag_topic")) {
      content.push({
        id: "flag",
        icon: "flag",
        name: I18n.t("topic.flag_topic.title"),
        __sk_row_type: "noopRow"
      });
    }

    return content;
  },

  autoHighlight() {},

  actions: {
    onSelect(value) {
      const topic = this.get("topic");

      if (!topic.get("id")) {
        return;
      }

      const refresh = () => {
        this._compute();
        this.deselect();
      };

      switch (value) {
        case "flag":
          this.showFlagTopic();
          refresh();
          break;
        case "bookmark":
          topic.toggleBookmark().then(refresh());
          break;
        case "share":
          this.appEvents.trigger(
            "share:url",
            topic.get("shareUrl"),
            $("#topic-footer-buttons")
          );
          refresh();
          break;
        case "invite":
          this.showInvite();
          refresh();
          break;
        default:
      }
    }
  }
});
