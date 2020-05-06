import Route from "@ember/routing/route";
import PreloadStore from "discourse/lib/preload-store";

export default Route.extend({
  setupController(controller) {
    controller.set("accountCreated", PreloadStore.get("accountCreated"));
  }
});
