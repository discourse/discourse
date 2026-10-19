import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { prettyJSON } from "discourse/lib/formatter";
import { gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class AiAgentResponseFormatEditor extends Component {
  @service modal;

  jsonSchema = {
    type: "array",
    uniqueItems: true,
    title: i18n("discourse_ai.ai_agent.response_format.modal.root_title"),
    items: {
      type: "object",
      title: i18n("discourse_ai.ai_agent.response_format.modal.key_title"),
      properties: {
        key: {
          type: "string",
        },
        type: {
          type: "string",
          enum: ["string", "integer", "boolean", "array"],
        },
        array_type: {
          type: "string",
          enum: ["string", "integer", "boolean"],
          options: {
            dependencies: {
              type: "array",
            },
          },
        },
      },
      required: ["key", "type"],
    },
  };

  get editorTitle() {
    return i18n("discourse_ai.ai_agent.response_format.title");
  }

  get responseFormatAsJSON() {
    return JSON.stringify(this.args.data.response_format);
  }

  get displayJSON() {
    const toDisplay = {};

    this.args.data.response_format.forEach((keyDesc) => {
      if (keyDesc.type === "array") {
        toDisplay[keyDesc.key] = `[${keyDesc.array_type}]`;
      } else {
        toDisplay[keyDesc.key] = keyDesc.type;
      }
    });

    return prettyJSON(toDisplay);
  }

  @action
  openModal() {
    this.modal.show(import("discourse/components/modal/json-schema-editor"), {
      model: {
        value: this.responseFormatAsJSON,
        updateValue: (value) =>
          this.args.form.set("response_format", JSON.parse(value)),
        settingName: this.editorTitle,
        jsonSchema: this.jsonSchema,
      },
    });
  }

  <template>
    <@form.Container @format="large" @title={{this.editorTitle}}>
      <div class="ai-agent-editor__response-format">
        {{#if (gt @data.response_format.length 0)}}
          <pre class="ai-agent-editor__response-format-pre">
            <code>{{this.displayJSON}}</code>
          </pre>
        {{else}}
          <div class="ai-agent-editor__response-format-none">
            {{i18n "discourse_ai.ai_agent.response_format.no_format"}}
          </div>
        {{/if}}

        <@form.Button
          class="btn-default"
          @action={{this.openModal}}
          @disabled={{@data.system}}
          @label="discourse_ai.ai_agent.response_format.open_modal"
        />
      </div>
    </@form.Container>
  </template>
}
