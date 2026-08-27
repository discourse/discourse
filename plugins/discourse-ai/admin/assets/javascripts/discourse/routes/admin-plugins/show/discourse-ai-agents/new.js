import { AUTO_GROUPS } from "discourse/lib/constants";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseAiAgentsNew extends DiscourseRoute {
  queryParams = {
    copyFrom: { refreshModel: true },
  };

  async model({ copyFrom }) {
    const sourceAgent = this.#findSourceAgent(copyFrom);
    if (sourceAgent) {
      const data = sourceAgent.toPOJO();
      data.id = null;
      data.name = i18n("discourse_ai.ai_agent.copy_name", {
        name: sourceAgent.name,
      });
      data.enabled = false;
      data.system = false;
      data.user = null;
      data.user_id = null;

      const duplicate = sourceAgent.fromPOJO(data);
      return this.store.createRecord("ai-agent", duplicate.createProperties());
    }

    const record = this.store.createRecord("ai-agent");
    record.set("allowed_group_ids", [AUTO_GROUPS.trust_level_0.id]);
    record.set("tools", []);
    record.set("rag_uploads", []);
    record.set("rag_document_sources", []);
    record.set("subagent_ids", []);
    // these match the defaults on the table
    record.set("rag_chunk_tokens", 374);
    record.set("rag_chunk_overlap_tokens", 10);
    record.set("rag_conversation_chunks", 10);
    record.set("allow_personal_messages", true);
    record.set("show_thinking", false);
    return record;
  }

  #findSourceAgent(copyFrom) {
    if (!copyFrom) {
      return;
    }

    const id = parseInt(copyFrom, 10);
    return this.modelFor("adminPlugins.show.discourse-ai-agents").content.find(
      (agent) => agent.id === id
    );
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allAgents",
      this.modelFor("adminPlugins.show.discourse-ai-agents")
    );
  }
}
