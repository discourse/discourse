import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class AiEmbedding extends RestModel {
  createProperties() {
    return this.getProperties(
      "id",
      "display_name",
      "dimensions",
      "provider",
      "tokenizer_class",
      "dimensions",
      "url",
      "api_key",
      "max_sequence_length",
      "provider_params",
      "pg_function",
      "embed_prompt",
      "search_prompt",
      "matryoshka_dimensions"
    );
  }

  updateProperties() {
    const attrs = this.createProperties();
    attrs.id = this.id;

    return attrs;
  }

  async testConfig() {
    return await ajax(`/admin/plugins/discourse-ai/ai-embeddings/test.json`, {
      data: { ai_embedding: this.createProperties() },
    });
  }

  workingCopy() {
    const attrs = this.createProperties();
    return this.store.createRecord("ai-embedding", attrs);
  }
}
