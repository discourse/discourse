import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { gt } from "truth-helpers";
import ModalJsonSchemaEditor from "discourse/components/modal/json-schema-editor";
import { prettyJSON } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

export default class AiPersonaResponseFormatEditor extends Component {
  @tracked showJsonEditorModal = false;

  jsonSchema = {
    type: "array",
    uniqueItems: true,
    title: i18n("discourse_ai.ai_persona.response_format.modal.root_title"),
    items: {
      type: "object",
      title: i18n("discourse_ai.ai_persona.response_format.modal.key_title"),
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
    return i18n("discourse_ai.ai_persona.response_format.title");
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
    this.showJsonEditorModal = true;
  }

  @action
  closeModal() {
    this.showJsonEditorModal = false;
  }

  @action
  updateResponseFormat(form, value) {
    form.set("response_format", JSON.parse(value));
  }

  <template>
    <@form.Container @title={{this.editorTitle}} @format="large">
      <div class="ai-persona-editor__response-format">
        {{#if (gt @data.response_format.length 0)}}
          <pre class="ai-persona-editor__response-format-pre">
            <code
            >{{this.displayJSON}}</code>
          </pre>
        {{else}}
          <div class="ai-persona-editor__response-format-none">
            {{i18n "discourse_ai.ai_persona.response_format.no_format"}}
          </div>
        {{/if}}

        <@form.Button
          @action={{this.openModal}}
          @label="discourse_ai.ai_persona.response_format.open_modal"
          @disabled={{@data.system}}
        />
      </div>
    </@form.Container>

    {{#if this.showJsonEditorModal}}
      <ModalJsonSchemaEditor
        @model={{hash
          value=this.responseFormatAsJSON
          updateValue=(fn this.updateResponseFormat @form)
          settingName=this.editorTitle
          jsonSchema=this.jsonSchema
        }}
        @closeModal={{this.closeModal}}
      />
    {{/if}}
  </template>
}
