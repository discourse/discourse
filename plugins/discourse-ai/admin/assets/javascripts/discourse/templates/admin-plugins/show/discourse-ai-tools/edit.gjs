import AiToolEditor from "../../../../../discourse/components/ai-tool-editor";

export default <template>
  <section class="ai-agent-tool-editor__current admin-detail pull-left">
    <AiToolEditor
      @llms={{@controller.llms}}
      @model={{@controller.model}}
      @presets={{@controller.presets}}
      @secrets={{@controller.secrets}}
      @settings={{@controller.settings}}
      @tools={{@controller.allTools}}
    />
  </section>
</template>
