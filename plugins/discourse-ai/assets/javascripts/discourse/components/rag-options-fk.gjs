import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import AiLlmSelector from "./ai-llm-selector";

export default class RagOptionsFk extends Component {
  @tracked showIndexingOptions = false;

  get indexingOptionsText() {
    return this.showIndexingOptions
      ? i18n("discourse_ai.rag.options.hide_indexing_options")
      : i18n("discourse_ai.rag.options.show_indexing_options");
  }

  get visionLlms() {
    return this.args.llms.filter((llm) => llm.vision_enabled);
  }

  @action
  toggleIndexingOptions(event) {
    this.showIndexingOptions = !this.showIndexingOptions;
    event.preventDefault();
    event.stopPropagation();
  }

  <template>
    {{#if @data.rag_uploads}}
      <a
        class="rag-options__indexing-options"
        href="#"
        {{on "click" this.toggleIndexingOptions}}
      >{{this.indexingOptionsText}}</a>
    {{/if}}

    {{#if this.showIndexingOptions}}
      <@form.Field
        @format="large"
        @name="rag_chunk_tokens"
        @title={{i18n "discourse_ai.rag.options.rag_chunk_tokens"}}
        @tooltip={{i18n "discourse_ai.rag.options.rag_chunk_tokens_help"}}
        @type="input-number"
        as |field|
      >
        <field.Control lang="en" step="any" />
      </@form.Field>

      <@form.Field
        @format="large"
        @name="rag_chunk_overlap_tokens"
        @title={{i18n "discourse_ai.rag.options.rag_chunk_tokens"}}
        @tooltip={{i18n
          "discourse_ai.rag.options.rag_chunk_overlap_tokens_help"
        }}
        @type="input-number"
        as |field|
      >
        <field.Control lang="en" step="any" />
      </@form.Field>

      {{#if @allowImages}}
        <@form.Field
          @format="large"
          @name="rag_llm_model_id"
          @title={{i18n "discourse_ai.rag.options.rag_llm_model"}}
          @tooltip={{i18n "discourse_ai.rag.options.rag_llm_model_help"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <AiLlmSelector
              class="ai-agent-editor__llms"
              @llms={{this.visionLlms}}
              @onChange={{field.set}}
              @value={{field.value}}
            />
          </field.Control>
        </@form.Field>
      {{/if}}
      {{yield}}
    {{/if}}
  </template>
}
