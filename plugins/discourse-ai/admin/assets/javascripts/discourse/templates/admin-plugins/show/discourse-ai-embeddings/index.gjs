import RouteTemplate from "ember-route-template";
import AiEmbeddingsListEditor from "../../../../../discourse/components/ai-embeddings-list-editor";

export default RouteTemplate(
  <template>
    <AiEmbeddingsListEditor @embeddings={{@controller.model}} />
  </template>
);
