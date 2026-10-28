import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class LiveRecordingsRoute extends Route {
  async model() {
    return await ajax("/admin/plugins/live/recordings.json");
  }
}
