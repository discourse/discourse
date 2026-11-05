import AiEmbeddingsListEditor from "../../../../components/ai-embeddings-list-editor.gjs";

export default <template>
  <AiEmbeddingsListEditor
    @currentEmbedding={{@controller.model}}
    @embeddings={{@controller.allEmbeddings}}
    @preset={{@controller.preset}}
  />
</template>
