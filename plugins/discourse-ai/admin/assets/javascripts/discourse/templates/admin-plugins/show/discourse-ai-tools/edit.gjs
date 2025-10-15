import AiToolEditor from "../../../../../discourse/components/ai-tool-editor";

<template>
  <section class="ai-persona-tool-editor__current admin-detail pull-left">
    <AiToolEditor
      @tools={{@controller.allTools}}
      @model={{@controller.model}}
      @presets={{@controller.presets}}
      @llms={{@controller.llms}}
      @settings={{@controller.settings}}
    />
  </section>
</template>
