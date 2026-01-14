import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import AiLlmSelector from "./ai-llm-selector";

export default class RagOptionsFk extends Component {
  @tracked showIndexingOptions = false;

  @action
  toggleIndexingOptions(event) {
    this.showIndexingOptions = !this.showIndexingOptions;
    event.preventDefault();
    event.stopPropagation();
  }

  get indexingOptionsText() {
    return this.showIndexingOptions
      ? i18n("discourse_ai.rag.options.hide_indexing_options")
      : i18n("discourse_ai.rag.options.show_indexing_options");
  }

  get visionLlms() {
    return this.args.llms.filter((llm) => llm.vision_enabled);
  }

  <template>
    {{#if @data.rag_uploads}}
      <a
        href="#"
        class="rag-options__indexing-options"
        {{on "click" this.toggleIndexingOptions}}
      >{{this.indexingOptionsText}}</a>
    {{/if}}

    {{#if this.showIndexingOptions}}
      <@form.Field
        @name="rag_chunk_tokens"
        @title={{i18n "discourse_ai.rag.options.rag_chunk_tokens"}}
        @tooltip={{i18n "discourse_ai.rag.options.rag_chunk_tokens_help"}}
        @format="large"
        as |field|
      >
        <field.Input @type="number" step="any" lang="en" />
      </@form.Field>

      <@form.Field
        @name="rag_chunk_overlap_tokens"
        @title={{i18n "discourse_ai.rag.options.rag_chunk_tokens"}}
        @tooltip={{i18n
          "discourse_ai.rag.options.rag_chunk_overlap_tokens_help"
        }}
        @format="large"
        as |field|
      >
        <field.Input @type="number" step="any" lang="en" />
      </@form.Field>

      {{#if @allowImages}}
        <@form.Field
          @name="rag_llm_model_id"
          @title={{i18n "discourse_ai.rag.options.rag_llm_model"}}
          @tooltip={{i18n "discourse_ai.rag.options.rag_llm_model_help"}}
          @format="large"
          as |field|
        >
          <field.Custom>
            <AiLlmSelector
              @value={{field.value}}
              @llms={{this.visionLlms}}
              @onChange={{field.set}}
              @class="ai-persona-editor__llms"
            />
          </field.Custom>
        </@form.Field>
      {{/if}}
      {{yield}}
    {{/if}}
  </template>
}
