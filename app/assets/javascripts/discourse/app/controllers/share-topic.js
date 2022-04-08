import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import discourseComputed, {
  afterRender,
} from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import Sharing from "discourse/lib/sharing";
import showModal from "discourse/lib/show-modal";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";
import Category from "discourse/models/category";

export default Controller.extend(
  ModalFunctionality,
  bufferedProperty("invite"),
  {
    topic: null,

    onShow() {
      this.set("showNotifyUsers", false);

      this._showRestrictedGroupWarning();
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

    @discourseComputed("topic.shareUrl")
    topicUrl(url) {
      return url ? getAbsoluteURL(url) : null;
    },

    @discourseComputed(
      "topic.{isPrivateMessage,invisible,category.read_restricted}"
    )
    sources(topic) {
      const privateContext =
        this.siteSettings.login_required ||
        (topic && topic.isPrivateMessage) ||
        (topic && topic.invisible) ||
        topic.category.read_restricted;

      return Sharing.activeSources(
        this.siteSettings.share_links,
        privateContext
      );
    },

    @action
    onChangeUsers(usernames) {
      this.set("users", usernames.uniq());
    },

    @action
    share(source) {
      this.set("showNotifyUsers", false);
      Sharing.shareSource(source, {
        title: this.topic.title,
        url: this.topicUrl,
      });
    },

    @action
    toggleNotifyUsers() {
      if (this.showNotifyUsers) {
        this.set("showNotifyUsers", false);
      } else {
        this.setProperties({
          showNotifyUsers: true,
          users: [],
        });
      }
    },

    @action
    notifyUsers() {
      if (this.users.length === 0) {
        return;
      }

      ajax(`/t/${this.topic.id}/invite-notify`, {
        type: "POST",
        data: { usernames: this.users },
      })
        .then(() => {
          this.setProperties({ showNotifyUsers: false });
          this.appEvents.trigger("modal-body:flash", {
            text: I18n.t("topic.share.notify_users.success", {
              count: this.users.length,
              username: this.users[0],
            }),
            messageClass: "success",
          });
        })
        .catch((error) => {
          this.appEvents.trigger("modal-body:flash", {
            text: extractError(error),
            messageClass: "error",
          });
        });
    },

    @action
    inviteUsers() {
      this.set("showNotifyUsers", false);
      const controller = showModal("create-invite");
      controller.set("inviteToTopic", true);
      controller.buffered.setProperties({
        topicId: this.topic.id,
        topicTitle: this.topic.title,
      });
    },
  }
);
