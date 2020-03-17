import Route from "@ember/routing/route";
import PreloadStore from "preload-store";

export default Route.extend({
  setupController(controller) {
    controller.set("accountCreated", PreloadStore.get("accountCreated"));
  }
});
