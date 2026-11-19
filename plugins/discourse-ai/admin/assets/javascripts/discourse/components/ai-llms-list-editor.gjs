import Component from "@glimmer/component";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import AiLlmEditor from "./ai-llm-editor.gjs";

export default class AiLlmsListEditor extends Component {
  @service adminPluginNavManager;

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.models.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-models"
    />
    <section class="ai-llm-list-editor admin-detail">
      <AiLlmEditor
        @llms={{@llms}}
        @llmTemplate={{@llmTemplate}}
        @model={{@currentLlm}}
      />
    </section>
  </template>
}
