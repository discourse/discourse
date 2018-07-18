import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["topic-footer-mobile-dropdown"],
  classNames: "topic-footer-mobile-dropdown",
  filterable: false,
  autoFilterable: false,
  allowInitialValueMutation: false,

  computeHeaderContent() {
    let content = this._super();
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
        name: I18n.t("topic.invite_reply.title")
      });
    }

    if (topic.get("bookmarked")) {
      content.push({
        id: "bookmark",
        icon: "bookmark",
        name: I18n.t("bookmarked.clear_bookmarks")
      });
    } else {
      content.push({
        id: "bookmark",
        icon: "bookmark",
        name: I18n.t("bookmarked.title")
      });
    }

    content.push({
      id: "share",
      icon: "link",
      name: I18n.t("topic.share.title")
    });

    if (details.get("can_flag_topic")) {
      content.push({
        id: "flag",
        icon: "flag",
        name: I18n.t("topic.flag_topic.title")
      });
    }

    return content;
  },

  autoHighlight() {},

  mutateValue(value) {
    const topic = this.get("topic");

    if (!topic.get("id")) {
      return;
    }

    const refresh = () => this.deselect(this.get("selection"));

    switch (value) {
      case "invite":
        this.attrs.showInvite();
        refresh();
        break;
      case "bookmark":
        topic.toggleBookmark().then(() => refresh());
        break;
      case "share":
        this.appEvents.trigger(
          "share:url",
          topic.get("shareUrl"),
          $("#topic-footer-buttons")
        );
        refresh();
        break;
      case "flag":
        this.attrs.showFlagTopic();
        refresh();
        break;
    }
  }
});
