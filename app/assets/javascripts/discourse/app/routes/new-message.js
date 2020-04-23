import { next } from "@ember/runloop";
import DiscourseRoute from "discourse/routes/discourse";
import User from "discourse/models/user";
import Group from "discourse/models/group";

export default DiscourseRoute.extend({
  beforeModel(transition) {
    const params = transition.to.queryParams;

    const groupName = params.groupname || params.group_name;

    if (this.currentUser) {
      this.replaceWith("discovery.latest").then(e => {
        if (params.username) {
          // send a message to a user
          User.findByUsername(encodeURIComponent(params.username))
            .then(user => {
              if (user.can_send_private_message_to_user) {
                next(() =>
                  e.send(
                    "createNewMessageViaParams",
                    user.username,
                    params.title,
                    params.body
                  )
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
            .then(result => {
              if (result.messageable) {
                next(() =>
                  e.send(
                    "createNewMessageViaParams",
                    groupName,
                    params.title,
                    params.body
                  )
                );
              } else {
                bootbox.alert(
                  I18n.t("composer.cant_send_pm", { username: groupName })
                );
              }
            })
            .catch(() => bootbox.alert(I18n.t("generic_error")));
        } else {
          e.send("createNewMessageViaParams", null, params.title, params.body);
        }
      });
    } else {
      $.cookie("destination_url", window.location.href);
      this.replaceWith("login");
    }
  }
});
