import { next } from "@ember/runloop";
import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class NewMessage extends DiscourseRoute {
  @service dialog;
  @service composer;
  @service router;

  beforeModel(transition) {
    const params = transition.to.queryParams;
    const userName = params.username;
    const groupName = params.groupname || params.group_name;

    if (!this.currentUser) {
      cookie("destination_url", window.location.href);
      this.router.replaceWith("login");
      return;
    }

    if (transition.from) {
      transition.abort();

      if (userName) {
        return this.openComposer(transition, userName);
      }

      if (groupName) {
        // send a message to a group
        return Group.messageable(groupName)
          .then((result) => {
            if (result.messageable) {
              this.openComposer(transition, groupName);
            } else {
              this.dialog.alert(
                i18n("composer.cant_send_pm", { username: groupName })
              );
            }
          })
          .catch(() =>
            this.dialog.alert(i18n("composer.create_message_error"))
          );
      }

      return this.openComposer(transition);
    } else {
      this.router
        .replaceWith("discovery.latest")
        .followRedirects()
        .then(() => {
          if (userName) {
            return this.openComposer(transition, userName);
          }

          if (groupName) {
            // send a message to a group
            return Group.messageable(groupName)
              .then((result) => {
                if (result.messageable) {
                  this.openComposer(transition, groupName);
                } else {
                  this.dialog.alert(
                    i18n("composer.cant_send_pm", { username: groupName })
                  );
                }
              })
              .catch(() =>
                this.dialog.alert(i18n("composer.create_message_error"))
              );
          }

          return this.openComposer(transition);
        });
    }
  }

  openComposer(transition, recipients) {
    next(() => {
      this.composer.openNewMessage({
        recipients,
        title: transition.to.queryParams.title,
        body: transition.to.queryParams.body,
      });
    });
  }
}
