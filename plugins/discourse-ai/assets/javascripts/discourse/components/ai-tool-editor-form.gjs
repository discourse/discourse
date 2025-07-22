import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, gt } from "truth-helpers";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import AiToolTestModal from "./modal/ai-tool-test-modal";
import RagOptionsFk from "./rag-options-fk";
import RagUploader from "./rag-uploader";

export default class AiToolEditorForm extends Component {
  @service modal;
  @service siteSettings;
  @service dialog;
  @service router;
  @service toasts;

  @tracked uploadedFiles = [];
  @tracked isSaving = false;

  PARAMETER_TYPES = [
    { name: "string", id: "string" },
    { name: "number", id: "number" },
    { name: "boolean", id: "boolean" },
    { name: "array", id: "array" },
  ];

  get formData() {
    const parameters = (this.args.editingModel.parameters ?? []).map(
      (parameter) => {
        const mappedParameter = {
          ...parameter,
        };
        mappedParameter.isEnum = parameter.enum && parameter.enum.length > 0;
        if (!mappedParameter.isEnum) {
          delete mappedParameter.enum;
        }
        return mappedParameter;
      }
    );

    return {
      name: this.args.editingModel.name || "",
      tool_name: this.args.editingModel.tool_name || "",
      description: this.args.editingModel.description || "",
      summary: this.args.editingModel.summary || "",
      parameters,
      script: this.args.editingModel.script || "",
      rag_uploads: this.args.editingModel.rag_uploads || [],
    };
  }

  @action
  toggleIsEnum(value, { name, parentName, set }) {
    if (value) {
      set(`${parentName}.enum`, [""]);
    } else {
      set(`${parentName}.enum`, []);
    }

    set(name, value);
  }

  @action
  async save(data) {
    this.isSaving = true;

    // we injected a isEnum thing, we need to clean it up
    const copiedData = JSON.parse(JSON.stringify(data));
    if (copiedData.parameters) {
      copiedData.parameters.forEach((parameter) => {
        if (!parameter.isEnum) {
          delete parameter.enum;
        }
        delete parameter.isEnum;
      });
    }

    try {
      await this.args.model.save(copiedData);

      this.toasts.success({
        data: { message: i18n("discourse_ai.tools.saved") },
        duration: "short",
      });

      if (!this.args.tools.any((tool) => tool.id === this.args.model.id)) {
        this.args.tools.pushObject(this.args.model);
      }

      await this.router.replaceWith(
        "adminPlugins.show.discourse-ai-tools.edit",
        this.args.model
      );
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.tools.confirm_delete"),

      didConfirm: async () => {
        await this.args.model.destroyRecord();
        this.args.tools.removeObject(this.args.model);
        this.router.transitionTo("adminPlugins.show.discourse-ai-tools.index");
      },
    });
  }

  @action
  updateUploads(addItemToCollection, uploads) {
    const uniqueUploads = uploads.filter(
      (upload) => !this.uploadedFiles.some((file) => file.id === upload.id)
    );
    addItemToCollection("rag_uploads", uniqueUploads);
    this.uploadedFiles = [...this.uploadedFiles, ...uniqueUploads];
  }

  @action
  removeUpload(form, upload) {
    this.uploadedFiles = this.uploadedFiles.filter(
      (file) => file.id !== upload.id
    );
    form.set("rag_uploads", this.uploadedFiles);
  }

  @action
  openTestModal() {
    this.modal.show(AiToolTestModal, {
      model: {
        tool: this.args.editingModel,
      },
    });
  }

  currentParameterSelection(data, index) {
    return data.parameters[index].type;
  }

  get ragUploadsDescription() {
    return this.siteSettings.rag_images_enabled
      ? i18n("discourse_ai.rag.uploads.description_with_images")
      : i18n("discourse_ai.rag.uploads.description");
  }

  @action
  exportTool() {
    const exportUrl = `/admin/plugins/discourse-ai/ai-tools/${this.args.model.id}/export.json`;
    window.location.href = getURL(exportUrl);
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="ai-tool-editor"
      as |form data|
    >
      {{! NAME }}
      <form.Field
        @name="name"
        @title={{i18n "discourse_ai.tools.name"}}
        @validation="required|length:1,100"
        @format="large"
        @tooltip={{i18n "discourse_ai.tools.name_help"}}
        as |field|
      >
        <field.Input class="ai-tool-editor__name" />
      </form.Field>

      {{! TOOL NAME }}
      <form.Field
        @name="tool_name"
        @title={{i18n "discourse_ai.tools.tool_name"}}
        @validation="required|length:1,100"
        @format="large"
        @tooltip={{i18n "discourse_ai.tools.tool_name_help"}}
        as |field|
      >
        <field.Input class="ai-tool-editor__tool_name" />
      </form.Field>

      {{! DESCRIPTION }}
      <form.Field
        @name="description"
        @title={{i18n "discourse_ai.tools.description"}}
        @validation="required|length:1,1000"
        @format="full"
        @tooltip={{i18n "discourse_ai.tools.description_help"}}
        as |field|
      >
        <field.Textarea
          @height={{60}}
          class="ai-tool-editor__description"
          placeholder={{i18n "discourse_ai.tools.description_help"}}
        />
      </form.Field>

      {{! SUMMARY }}
      <form.Field
        @name="summary"
        @title={{i18n "discourse_ai.tools.summary"}}
        @validation="required|length:1,255"
        @format="large"
        @tooltip={{i18n "discourse_ai.tools.summary_help"}}
        as |field|
      >
        <field.Input class="ai-tool-editor__summary" />
      </form.Field>

      {{! PARAMETERS }}
      <form.Collection @name="parameters" as |collection index collectionData|>
        <form.Container class="ai-tool-parameter">
          <form.Row as |row|>
            <row.Col @size={{6}}>
              <collection.Field
                @name="name"
                @title={{i18n "discourse_ai.tools.parameter_name"}}
                @validation="required|length:1,100"
                @format="full"
                as |field|
              >
                <field.Input />
              </collection.Field>
            </row.Col>

            <row.Col @size={{6}}>
              <collection.Field
                @name="type"
                @title={{i18n "discourse_ai.tools.parameter_type"}}
                @validation="required"
                @format="full"
                as |field|
              >
                <field.Select as |select|>
                  {{#each this.PARAMETER_TYPES as |type|}}
                    <select.Option
                      @value={{type.id}}
                    >{{type.name}}</select.Option>
                  {{/each}}
                </field.Select>
              </collection.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{12}}>
              <collection.Field
                @name="description"
                @title={{i18n "discourse_ai.tools.parameter_description"}}
                @validation="required|length:1,1000"
                @format="full"
                as |field|
              >
                <field.Input class="ai-tool-editor__parameter-description" />
              </collection.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col>
              <collection.Field @name="required" @title="Required" as |field|>
                <field.Checkbox />
              </collection.Field>
            </row.Col>

            <row.Col>
              <collection.Field
                @name="isEnum"
                @title="Enum"
                @onSet={{this.toggleIsEnum}}
                as |field|
              >
                <field.Checkbox />
              </collection.Field>
            </row.Col>

            {{#if collectionData.isEnum}}
              <row.Col @size={{8}}>
                <collection.Collection @name="enum" as |child childIndex|>
                  <form.Container class="ai-tool-parameter__enum-values">
                    <child.Field
                      @title={{i18n "discourse_ai.tools.enum_value"}}
                      @validation="required"
                      as |field|
                    >
                      <field.Input />

                      {{#if
                        (and
                          (gt collectionData.enum.length 1) (gt childIndex 0)
                        )
                      }}
                        <form.Button
                          class="btn-danger"
                          @icon="trash-can"
                          @action={{fn child.remove childIndex}}
                        />
                      {{/if}}
                    </child.Field>
                  </form.Container>
                </collection.Collection>
              </row.Col>

              <row.Col @size={{8}}>
                <form.Button
                  @icon="plus"
                  @label="discourse_ai.tools.add_enum_value"
                  @action={{fn
                    form.addItemToCollection
                    (concat "parameters." index ".enum")
                    ""
                  }}
                />
              </row.Col>
            {{/if}}
          </form.Row>
          <form.Row as |row|>
            <row.Col class="ai-tool-parameter-actions">
              <form.Button
                @label="discourse_ai.tools.remove_parameter"
                @icon="trash-can"
                @action={{fn collection.remove index}}
                class="btn-danger"
              />
            </row.Col>
          </form.Row>
        </form.Container>
      </form.Collection>

      <form.Button
        @icon="plus"
        @label="discourse_ai.tools.add_parameter"
        @action={{fn
          form.addItemToCollection
          "parameters"
          (hash
            name="" type="string" description="" required=false isEnum=false
          )
        }}
      />

      {{! SCRIPT }}
      <form.Field
        @name="script"
        @title={{i18n "discourse_ai.tools.script"}}
        @validation="required|length:1,100000"
        @format="full"
        as |field|
      >
        <field.Code @lang="javascript" @height={{600}} />
      </form.Field>

      {{! UPLOADS }}
      {{#if this.siteSettings.ai_embeddings_enabled}}
        <form.Field
          @name="rag_uploads"
          @title={{i18n "discourse_ai.rag.uploads.title"}}
          @tooltip={{this.ragUploadsDescription}}
          @format="full"
          as |field|
        >
          <field.Custom>
            <RagUploader
              @target={{@editingModel}}
              @updateUploads={{fn this.updateUploads form.addItemToCollection}}
              @onRemove={{fn this.removeUpload form}}
              @allowImages={{@settings.rag_images_enabled}}
            />
            <RagOptionsFk
              @form={{form}}
              @data={{data}}
              @llms={{@llms}}
              @allowImages={{@settings.rag_images_enabled}}
            />
          </field.Custom>
        </form.Field>
      {{/if}}

      <form.Actions>
        {{#unless @isNew}}
          <form.Button
            @label="discourse_ai.tools.test"
            @action={{this.openTestModal}}
            class="ai-tool-editor__test-button"
          />
          <form.Button
            @label="discourse_ai.tools.export"
            @action={{this.exportTool}}
            class="ai-tool-editor__export"
          />
          <form.Button
            @label="discourse_ai.tools.delete"
            @icon="trash-can"
            @action={{this.delete}}
            class="btn-danger ai-tool-editor__delete"
          />
        {{/unless}}

        <form.Submit
          @label="discourse_ai.tools.save"
          class="ai-tool-editor__save"
        />
      </form.Actions>
    </Form>
  </template>
}
