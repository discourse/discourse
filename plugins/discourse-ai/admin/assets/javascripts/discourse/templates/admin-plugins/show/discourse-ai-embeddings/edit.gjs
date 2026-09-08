import AiEmbeddingsListEditor from "../../../../components/ai-embeddings-list-editor";

export default <template>
  <AiEmbeddingsListEditor
    @currentEmbedding={{@controller.model}}
    @embeddings={{@controller.allEmbeddings}}
  />
</template>
