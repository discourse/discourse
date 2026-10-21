import Component from "@glimmer/component";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import AiEmbeddingEditor from "./ai-embedding-editor.gjs";

export default class AiEmbeddingsListEditor extends Component {
  @service adminPluginNavManager;

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.models.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-models"
    />
    <section class="ai-embeddings-list-editor admin-detail">
      <AiEmbeddingEditor
        @embeddings={{@embeddings}}
        @model={{@currentEmbedding}}
        @preset={{@preset}}
      />
    </section>
  </template>
}
