import { AUTO_GROUPS } from "discourse/lib/constants";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiPersonasNew extends DiscourseRoute {
  async model() {
    const record = this.store.createRecord("ai-persona");
    record.set("allowed_group_ids", [AUTO_GROUPS.trust_level_0.id]);
    record.set("rag_uploads", []);
    // these match the defaults on the table
    record.set("rag_chunk_tokens", 374);
    record.set("rag_chunk_overlap_tokens", 10);
    record.set("rag_conversation_chunks", 10);
    record.set("allow_personal_messages", true);
    record.set("tool_details", false);
    return record;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allPersonas",
      this.modelFor("adminPlugins.show.discourse-ai-personas")
    );
  }
}
