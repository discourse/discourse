import { service } from "@ember/service";
import ShareTargetModal from "discourse/components/modal/share-target";
import { defaultHomepage } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  @service appEvents;
  @service currentUser;
  @service modal;
  @service router;
  @service("shared-content") sharedContent;

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
        this.modal.show(ShareTargetModal, { model: shared });
      });
    }

    // The share-target route has no UI of its own — send the user to the
    // homepage; the modal (if any) opens once that page has rendered.
    this.router.replaceWith(`discovery.${defaultHomepage()}`);
  }

  #hasContent({ title, text, url, files }) {
    return !!(title || text || url || files?.length);
  }
}
