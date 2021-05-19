import DiscourseRoute from "discourse/routes/discourse";
import Group from "discourse/models/group";
import I18n from "I18n";
import User from "discourse/models/user";
import bootbox from "bootbox";
import cookie from "discourse/lib/cookie";
import { next } from "@ember/runloop";

export default DiscourseRoute.extend({
  beforeModel(transition) {
    const params = transition.to.queryParams;

    const groupName = params.groupname || params.group_name;

    if (this.currentUser) {
      this.replaceWith("discovery.latest").then((e) => {
        if (params.username) {
          // send a message to a user
          User.findByUsername(encodeURIComponent(params.username))
            .then((user) => {
              if (user.can_send_private_message_to_user) {
                next(() =>
                  e.send("createNewMessageViaParams", {
                    recipients: user.username,
                    topicTitle: params.title,
                    topicBody: params.body,
                  })
                );
              } else {
                bootbox.alert(
                  I18n.t("composer.cant_send_pm", { username: user.username })
                );
              }
            })
            .catch(() => bootbox.alert(I18n.t("generic_error")));
        } else if (groupName) {
          // send a message to a group
          Group.messageable(groupName)
            .then((result) => {
              if (result.messageable) {
                next(() =>
                  e.send("createNewMessageViaParams", {
                    recipients: groupName,
                    topicTitle: params.title,
                    topicBody: params.body,
                  })
                );
              } else {
                bootbox.alert(
                  I18n.t("composer.cant_send_pm", { username: groupName })
                );
              }
            })
            .catch(() => bootbox.alert(I18n.t("generic_error")));
        } else {
          e.send("createNewMessageViaParams", {
            topicTitle: params.title,
            topicBody: params.body,
          });
        }
      });
    } else {
      cookie("destination_url", window.location.href);
      this.replaceWith("login");
    }
  },
});
