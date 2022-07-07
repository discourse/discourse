import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
createWidget("timeline-footer-controls", {
  tagName: "div.timeline-footer-controls",

  html(attrs) {
    const controls = [];
    const { currentUser, fullScreen, topic, notificationLevel } = attrs;

    if (
      this.siteSettings.summary_timeline_button &&
      !fullScreen &&
      topic.has_summary &&
      !topic.postStream.summary
    ) {
      controls.push(
        this.attach("button", {
          className: "show-summary btn-small",
          icon: "layer-group",
          label: "summary.short_label",
          title: "summary.short_title",
          action: "showSummary",
        })
      );
    }

    if (currentUser && !fullScreen) {
      if (topic.get("details.can_create_post")) {
        controls.push(
          this.attach("button", {
            className: "btn-default create reply-to-post",
            icon: "reply",
            title: "topic.reply.help",
            action: "replyToPost",
          })
        );
      }
    }

    if (fullScreen) {
      controls.push(
        this.attach("button", {
          className: "jump-to-post",
          title: "topic.progress.jump_prompt_long",
          label: "topic.progress.jump_prompt",
          action: "jumpToPostPrompt",
        })
      );
    }

    if (currentUser) {
      controls.push(
        new ComponentConnector(
          this,
          "topic-notifications-button",
          {
            notificationLevel,
            topic,
            showFullTitle: false,
            appendReason: false,
            placement: "bottom-end",
            mountedAsWidget: true,
            showCaret: false,
          },
          ["notificationLevel"]
        )
      );
      if (this.site.mobileView) {
        controls.push(
          this.attach("topic-admin-menu-button", {
            topic,
            addKeyboardTargetClass: true,
            openUpwards: true,
          })
        );
      }
    }

    return controls;
  },
});
