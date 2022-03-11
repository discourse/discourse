import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import Sharing from "discourse/lib/sharing";
import showModal from "discourse/lib/show-modal";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";
import Category from "discourse/models/category";
import { scheduleOnce } from "@ember/runloop";

export default Controller.extend(
  ModalFunctionality,
  bufferedProperty("invite"),
  {
    topic: null,
    post: null,
    allowInvites: false,
    restrictedGroups: null,

    onShow() {
      this.setProperties({
        topic: null,
        post: null,
        allowInvites: false,
      });

      if (this.model && this.model.read_restricted) {
        this.restrictedGroupWarning();
      }

      scheduleOnce("afterRender", this, this.selectUrl);
    },

    selectUrl() {
      const input = document.querySelector("input.invite-link");
      if (input && !this.site.mobileView) {
        // if the input is auto-focused on mobile, iOS requires two taps of the copy button
        input.setSelectionRange(0, this.url.length);
        input.focus();
      }
    },

    @discourseComputed("post.shareUrl", "topic.shareUrl")
    url(postUrl, topicUrl) {
      if (postUrl) {
        return getAbsoluteURL(postUrl);
      } else if (topicUrl) {
        return getAbsoluteURL(topicUrl);
      }
    },

    @discourseComputed(
      "topic.{isPrivateMessage,invisible,category.read_restricted}"
    )
    sources(topic) {
      const privateContext =
        this.siteSettings.login_required ||
        topic?.isPrivateMessage ||
        topic?.invisible ||
        topic?.category?.read_restricted;

      return Sharing.activeSources(
        this.siteSettings.share_links,
        privateContext
      );
    },

    @action
    share(source) {
      Sharing.shareSource(source, {
        title: this.topic.title,
        url: this.url,
      });
    },

    @action
    inviteUsers() {
      const controller = showModal("create-invite");
      controller.setProperties({
        inviteToTopic: true,
        topics: [this.topic],
      });
      controller.buffered.setProperties({
        topicId: this.topic.id,
        topicTitle: this.topic.title,
      });
    },

    restrictedGroupWarning() {
      this.appEvents.on("modal:body-shown", () => {
        let restrictedGroups;
        Category.reloadBySlugPath(this.model.slug).then((result) => {
          restrictedGroups = result.category.group_permissions.map(
            (g) => g.group_name
          );

          if (restrictedGroups) {
            const message = I18n.t("topic.share.restricted_groups", {
              count: restrictedGroups.length,
              groupNames: restrictedGroups.join(", "),
            });
            this.flash(message, "warning");
          }
        });
      });
    },
  }
);
