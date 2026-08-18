import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

const HIDE_SIDEBAR_KEY = "sidebar-hidden";

export default class TopicZoomRoute extends DiscourseRoute {
  @service embeddableChat;
  @service keyValueStore;
  @service store;

  activate() {
    this.embeddableChat.closeChatVisibility();

    // The /zoom page is a full-screen webinar: collapse the sidebar for the
    // visit. The snapshot lets a manual toggle be undone on exit rather than persisted.
    this.sidebarHiddenSnapshot = this.keyValueStore.getItem(HIDE_SIDEBAR_KEY);
    this.controllerFor("application").showSidebar = false;
  }

  deactivate() {
    super.deactivate(...arguments);

    // Roll back any persistence core's toggleSidebar wrote while on this page.
    // The stored value is always the string "true", so any falsy snapshot means
    // the preference was not collapsed.
    if (this.sidebarHiddenSnapshot) {
      this.keyValueStore.setItem(HIDE_SIDEBAR_KEY, this.sidebarHiddenSnapshot);
    } else {
      this.keyValueStore.removeItem(HIDE_SIDEBAR_KEY);
    }

    // Drop the override so the sidebar falls back to the user's stored state.
    this.controllerFor("application").showSidebar = null;
    this.controllerFor("topic").set("model", null);
  }

  async model(params) {
    const topic = this.store.createRecord("topic", { id: params.topic_id });

    // Populates the topic (chat_channel_id, slug, post stream) from the
    // server-preloaded payload when available, falling back to a request.
    await topic.postStream.refresh();

    return topic;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    this.controllerFor("topic").set("model", model);
  }
}
