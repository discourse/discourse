import Controller from "@ember/controller";
import urlFlagSet from "discourse/plugins/live/discourse/lib/live/url-flag";

export default class LiveRoomController extends Controller {
  queryParams = ["chat", "join", "widget"];
  chat = false;
  join = false;
  // Typed as a string rather than a boolean so that a valueless `?widget`
  // survives deserialization as "" instead of being coerced to false.
  widget = null;

  get dockOnJoin() {
    return urlFlagSet(this.widget);
  }
}
