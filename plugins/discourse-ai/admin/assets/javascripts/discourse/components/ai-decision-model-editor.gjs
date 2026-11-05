import Component from "@glimmer/component";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import AiDecisionModelEditorForm from "./ai-decision-model-editor-form.gjs";

export default class AiDecisionModelEditor extends Component {
  @service adminPluginNavManager;

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.models.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-models"
    />
    <section class="admin-detail">
      <AiDecisionModelEditorForm
        @decisionModels={{@decisionModels}}
        @model={{@model}}
        @preset={{@preset}}
      />
    </section>
  </template>
}
