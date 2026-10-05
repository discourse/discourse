import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import DiscourseRoute from "discourse/routes/discourse";

export default class Transcript extends DiscourseRoute {
  @service currentUser;
  @service composer;
  @service router;

  async model(params) {
    if (!this.currentUser) {
      this.send("showLogin");
      return;
    }

    await this.router
      .replaceWith(homepageNavigationDestination())
      .followRedirects();

    try {
      const { content: body } = await ajax(`/chat-transcript/${params.secret}`);
      this.composer.openNewTopic({ body });
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
