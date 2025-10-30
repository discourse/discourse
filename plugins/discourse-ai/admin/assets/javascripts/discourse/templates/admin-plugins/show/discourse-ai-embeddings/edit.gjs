import AiEmbeddingsListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-embeddings-list-editor";

export default <template>
  <AiEmbeddingsListEditor
    @embeddings={{@controller.allEmbeddings}}
    @currentEmbedding={{@controller.model}}
  />
</template>
