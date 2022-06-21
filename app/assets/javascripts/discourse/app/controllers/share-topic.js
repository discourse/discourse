import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import discourseComputed, {
  afterRender,
} from "discourse-common/utils/decorators";
import { longDateNoYear } from "discourse/lib/formatter";
import Sharing from "discourse/lib/sharing";
import showModal from "discourse/lib/show-modal";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";
import Category from "discourse/models/category";
import { getOwner } from "discourse-common/lib/get-owner";

export default Controller.extend(
  ModalFunctionality,
  bufferedProperty("invite"),
  {
    topic: null,
    post: null,
    allowInvites: false,

    onShow() {
      this.setProperties({
        topic: null,
        post: null,
        allowInvites: false,
      });

      this._showRestrictedGroupWarning();
      this._selectUrl();
    },

    @afterRender
    _showRestrictedGroupWarning() {
      if (!this.model) {
        return;
      }

      Category.fetchVisibleGroups(this.model.id).then((result) => {
        if (result.groups.length > 0) {
          this.flash(
            I18n.t("topic.share.restricted_groups", {
              count: result.groups.length,
              groupNames: result.groups.join(", "),
            }),
            "warning"
          );
        }
      });
    },

    @afterRender
    _selectUrl() {
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

    @discourseComputed("post.created_at", "post.wiki", "post.last_wiki_edit")
    displayDate(createdAt, wiki, lastWikiEdit) {
      const date = wiki && lastWikiEdit ? lastWikiEdit : createdAt;
      return longDateNoYear(new Date(date));
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

    @action
    replyAsNewTopic() {
      const postStream = this.topic.postStream;
      const postId = this.post?.id || postStream.findPostIdForPostNumber(1);
      const post = postStream.findLoadedPost(postId);
      const topicController = getOwner(this).lookup("controller:topic");
      topicController.actions.replyAsNewTopic.call(topicController, post);
      this.send("closeModal");
    },
  }
);
