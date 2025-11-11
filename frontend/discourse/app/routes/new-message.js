import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class extends DiscourseRoute {
  @service composer;
  @service dialog;
  @service router;

  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
      return;
    }

    const { queryParams: params } = transition.to;

    // when navigating from another ember route
    if (transition.from) {
      transition.abort();
      this.#openComposerWithPrefilledValues(params);
      return;
    }

    // when landing on the route from a full page load
    this.router
      .replaceWith(`discovery.${defaultHomepage()}`)
      .followRedirects()
      .then(() => this.#openComposerWithPrefilledValues(params));
  }

  #openComposer({ title, body }, recipients = "") {
    next(() => this.composer.openNewMessage({ recipients, title, body }));
  }

  #openComposerWithPrefilledValues(params) {
    const username = params.username;
    const groupname = params.groupname || params.group_name;

    if (username) {
      this.#openComposer(params, username);
      return;
    }

    if (groupname) {
      Group.messageable(groupname)
        .then(({ messageable }) => {
          if (messageable) {
            this.#openComposer(params, groupname);
          } else {
            this.dialog.alert(
              i18n("composer.cant_send_pm", { username: groupname })
            );
          }
        })
        .catch(() => this.dialog.alert(i18n("composer.create_message_error")));
      return;
    }

    this.#openComposer(params);
  }
}
