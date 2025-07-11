import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";

export default class Transcript extends DiscourseRoute {
  @service currentUser;
  @service composer;
  @service router;

  async model(params) {
    if (!this.currentUser) {
      this.session.set("shouldRedirectToUrl", window.location.href);
      this.router.replaceWith("login");
      return;
    }

    await this.router.replaceWith("discovery.latest").followRedirects();

    try {
      const result = await ajax(`/chat-transcript/${params.secret}`);
      this.composer.openNewTopic({
        body: result.content,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
