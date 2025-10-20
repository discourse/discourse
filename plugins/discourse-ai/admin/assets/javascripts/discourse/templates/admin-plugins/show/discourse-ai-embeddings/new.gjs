import RouteTemplate from "ember-route-template";
import AiEmbeddingsListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-embeddings-list-editor";

export default RouteTemplate(
  <template>
    <AiEmbeddingsListEditor
      @embeddings={{@controller.allEmbeddings}}
      @currentEmbedding={{@controller.model}}
    />
  </template>
);
