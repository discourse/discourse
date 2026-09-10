import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VoiceAgentIntegrationsRoute extends DiscourseRoute {
  @service store;

  async model() {
    const [response, rooms] = await Promise.all([
      ajax("/admin/plugins/voice/agent-integrations"),
      this.store.findAll("voice-room"),
    ]);

    return { integrations: response.integrations, bots: response.bots, rooms };
  }
}
