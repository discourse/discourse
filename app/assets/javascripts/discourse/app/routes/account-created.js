import PreloadStore from "discourse/lib/preload-store";
import Route from "@ember/routing/route";

export default Route.extend({
  setupController(controller) {
    controller.set("accountCreated", PreloadStore.get("accountCreated"));
  },
});
