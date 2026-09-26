import { service } from "discourse/lib/service";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import DiscourseRoute from "discourse/routes/discourse";
import AppEventsService from "discourse/services/app-events";
import CurrentUserService from "discourse/services/current-user";
import ModalService from "discourse/services/modal";
import SharedContentService from "discourse/services/shared-content";

export default class extends DiscourseRoute {
  @service(() => AppEventsService) appEvents;
  @service(() => CurrentUserService) currentUser;
  @service(() => ModalService) modal;
  @service router;
  @service(() => SharedContentService) sharedContent;

  async beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
      return;
    }

    const shared = await this.sharedContent.readShared();
    await this.sharedContent.clearShared();

    if (shared && this.#hasContent(shared)) {
      // We arrive here from the service worker redirect while the app is still
      // booting, so the modal container isn't mounted yet — opening the modal
      // now would be lost. Wait for the first rendered page instead;
      // `page:changed` fires after a route has rendered.
      this.appEvents.one("page:changed", () => {
        this.modal.show(
          () => import("discourse/components/modal/share-target"),
          { model: shared }
        );
      });
    }

    // The share-target route has no UI of its own — send the user to the
    // homepage; the modal (if any) opens once that page has rendered.
    this.router.replaceWith(homepageNavigationDestination());
  }

  #hasContent({ title, text, url, files }) {
    return !!(title || text || url || files?.length);
  }
}
