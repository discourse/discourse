import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class VoiceRecordingsRoute extends Route {
  async model() {
    return await ajax("/admin/plugins/voice/recordings.json");
  }
}
