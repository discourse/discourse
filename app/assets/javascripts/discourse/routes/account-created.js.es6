import PreloadStore from "preload-store";

export default Ember.Route.extend({
  setupController(controller) {
    controller.set("accountCreated", PreloadStore.get("accountCreated"));
  }
});
