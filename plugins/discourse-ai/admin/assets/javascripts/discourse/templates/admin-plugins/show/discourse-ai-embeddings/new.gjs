import AiEmbeddingsListEditor from "../../../../../discourse/components/ai-embeddings-list-editor";

<template>
  <AiEmbeddingsListEditor
    @embeddings={{@controller.allEmbeddings}}
    @currentEmbedding={{@controller.model}}
  />
</template>
