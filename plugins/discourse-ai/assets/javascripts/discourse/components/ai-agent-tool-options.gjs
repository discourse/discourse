import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AiLlmSelector from "./ai-llm-selector";

export default class AiAgentToolOptions extends Component {
  get showToolOptions() {
    const allTools = this.args.allTools;
    if (!allTools || !this.args.data.tools) {
      return false;
    }
    return this.args.data?.tools.some(
      (tool) => allTools.find((item) => item.id === tool)?.options
    );
  }

  get toolsMetadata() {
    const metadata = {};

    this.args.allTools.map((t) => {
      metadata[t.id] = {
        name: t.name,
        ...t?.options,
      };
    });

    return metadata;
  }

  @action
  formObjectKeys(toolOptions) {
    return toolOptions ? Object.keys(toolOptions) : [];
  }

  @action
  toolOptionKeys(toolId) {
    // this is important, some tools may not have all options defined (for example if a tool option is added)
    const metadata = this.toolsMetadata[toolId];
    if (!metadata) {
      return [];
    }

    // a bit more verbose for clarity of our selection
    const availableOptions = Object.keys(metadata).filter((k) => k !== "name");
    return availableOptions;
  }

  fieldTypeForOption(type) {
    switch (type) {
      case "enum":
        return "select";
      case "llm":
        return "custom";
      case "boolean":
        return "checkbox";
      case "text":
        return "textarea";
      default:
        return "input";
    }
  }

  <template>
    {{#if this.showToolOptions}}
      <@form.Container
        @title={{i18n "discourse_ai.ai_agent.tool_options"}}
        @direction="column"
        @format="full"
      >
        <@form.Object
          @name="toolOptions"
          @title={{i18n "discourse_ai.ai_agent.tool_options"}}
          as |toolObj optsPerTool|
        >
          {{#each (this.formObjectKeys optsPerTool) as |toolId|}}
            <div class="ai-agent-editor__tool-options">
              {{#let (get this.toolsMetadata toolId) as |toolMeta|}}
                <div class="ai-agent-editor__tool-options-name">
                  {{toolMeta.name}}
                </div>
                <toolObj.Object @name={{toolId}} as |optionsObj|>
                  {{#each (this.toolOptionKeys toolId) as |optionName|}}
                    {{#let (get toolMeta optionName) as |optionMeta|}}
                      <optionsObj.Field
                        @name={{optionName}}
                        @title={{optionMeta.name}}
                        @helpText={{optionMeta.description}}
                        @format="full"
                        @type={{this.fieldTypeForOption optionMeta.type}}
                        as |field|
                      >
                        {{#if (eq optionMeta.type "enum")}}
                          <field.Control @includeNone={{false}} as |select|>
                            {{#each optionMeta.values as |v|}}
                              <select.Option @value={{v}}>{{v}}</select.Option>
                            {{/each}}
                          </field.Control>
                        {{else if (eq optionMeta.type "llm")}}
                          <field.Control>
                            <AiLlmSelector
                              @value={{field.value}}
                              @llms={{@llms}}
                              @onChange={{field.set}}
                              class="ai-agent-tool-option-editor__llms"
                            />
                          </field.Control>
                        {{else if (eq optionMeta.type "boolean")}}
                          <field.Control />
                        {{else if (eq optionMeta.type "text")}}
                          <field.Control />
                        {{else}}
                          <field.Control />
                        {{/if}}
                      </optionsObj.Field>
                    {{/let}}
                  {{/each}}
                </toolObj.Object>
              {{/let}}
            </div>
          {{/each}}
        </@form.Object>
      </@form.Container>
    {{/if}}
  </template>
}
