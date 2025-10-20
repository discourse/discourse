import RouteTemplate from "ember-route-template";
import AiToolEditor from "discourse/plugins/discourse-ai/discourse/components/ai-tool-editor";

export default RouteTemplate(
  <template>
    <section class="ai-persona-tool-editor__current admin-detail pull-left">
      <AiToolEditor
        @tools={{@controller.allTools}}
        @model={{@controller.model}}
        @presets={{@controller.presets}}
        @llms={{@controller.llms}}
        @settings={{@controller.settings}}
        @selectedPreset={{@controller.selectedPreset}}
      />
    </section>
  </template>
);
