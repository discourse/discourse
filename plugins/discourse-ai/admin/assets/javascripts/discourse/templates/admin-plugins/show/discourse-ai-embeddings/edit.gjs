import AiEmbeddingsListEditor from "../../../../../discourse/components/ai-embeddings-list-editor";

export default <template>
  <AiEmbeddingsListEditor
    @embeddings={{@controller.allEmbeddings}}
    @currentEmbedding={{@controller.model}}
  />
</template>
