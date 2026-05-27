import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsRoute extends DiscourseRoute {
  @service store;

  async model() {
    const [tools, mcpServers] = await Promise.all([
      this.store.findAll("ai-tool"),
      this.store.findAll("ai-mcp-server"),
    ]);

    return { tools, mcpServers };
  }
}
