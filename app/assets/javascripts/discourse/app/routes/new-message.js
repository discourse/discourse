import DiscourseRoute from "discourse/routes/discourse";
import Group from "discourse/models/group";
import I18n from "I18n";
import cookie from "discourse/lib/cookie";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  dialog: service(),
  composer: service(),
  router: service(),

  beforeModel(transition) {
    const params = transition.to.queryParams;

    const groupName = params.groupname || params.group_name;

    if (this.currentUser) {
      this.router
        .replaceWith("discovery.latest")
        .followRedirects()
        .then(() => {
          if (params.username) {
            this.composer.openNewMessage({
              recipients: params.username,
              title: params.title,
              body: params.body,
            });
          } else if (groupName) {
            // send a message to a group
            Group.messageable(groupName)
              .then((result) => {
                if (result.messageable) {
                  next(() =>
                    this.composer.openNewMessage({
                      recipients: groupName,
                      title: params.title,
                      body: params.body,
                    })
                  );
                } else {
                  this.dialog.alert(
                    I18n.t("composer.cant_send_pm", { username: groupName })
                  );
                }
              })
              .catch(() => this.dialog.alert(I18n.t("generic_error")));
          } else {
            this.composer.openNewMessage({
              title: params.title,
              body: params.body,
            });
          }
        });
    } else {
      cookie("destination_url", window.location.href);
      this.router.replaceWith("login");
    }
  },
});
