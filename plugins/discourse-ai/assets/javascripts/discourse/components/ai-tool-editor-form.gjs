import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import getURL from "discourse/lib/get-url";
import { and, eq, gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { toPlainObject } from "../lib/utilities";
import AiSecretSelector from "./ai-secret-selector";
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

  ITEM_TYPES = [
    { name: "string", id: "string" },
    { name: "number", id: "number" },
    { name: "boolean", id: "boolean" },
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

    // FormKit uses Immer proxies which cause issues when passed to upload handlers.
    // Convert to plain objects to ensure compatibility.
    const ragUploads = this.args.editingModel.rag_uploads || [];
    const plainRagUploads =
      ragUploads.length > 0 ? toPlainObject(ragUploads) : [];

    const secretBindingMap = Object.fromEntries(
      (this.args.editingModel.secret_bindings || []).map((binding) => [
        binding.alias,
        binding.ai_secret_id,
      ])
    );
    const secretContracts = (this.args.editingModel.secret_contracts ?? []).map(
      (contract) => ({
        ...contract,
        ai_secret_id:
          secretBindingMap[contract.alias] || contract.ai_secret_id || null,
      })
    );

    return {
      name: this.args.editingModel.name || "",
      tool_name: this.args.editingModel.tool_name || "",
      description: this.args.editingModel.description || "",
      summary: this.args.editingModel.summary || "",
      parameters,
      secret_contracts: secretContracts,
      script: this.args.editingModel.script || "",
      rag_uploads: plainRagUploads,
    };
  }

  get secretOptions() {
    return this.args.secrets || [];
  }

  get ragUploadsDescription() {
    return this.siteSettings.rag_images_enabled
      ? i18n("discourse_ai.rag.uploads.description_with_images")
      : i18n("discourse_ai.rag.uploads.description");
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

  cleanFormData(data) {
    const copiedData = toPlainObject(data);
    if (copiedData.parameters) {
      copiedData.parameters.forEach((parameter) => {
        if (!parameter.isEnum) {
          delete parameter.enum;
        }
        delete parameter.isEnum;
        if (parameter.type !== "array") {
          delete parameter.item_type;
        }
      });
    }

    if (copiedData.secret_contracts) {
      copiedData.secret_bindings = copiedData.secret_contracts.map(
        ({ alias, ai_secret_id }) => ({
          alias,
          ai_secret_id,
        })
      );
      copiedData.secret_contracts = copiedData.secret_contracts.map(
        ({ alias: contractAlias }) => ({
          alias: contractAlias,
        })
      );
    } else {
      copiedData.secret_bindings = [];
    }

    return copiedData;
  }

  @action
  async save(data) {
    this.isSaving = true;
    const copiedData = this.cleanFormData(data);

    try {
      await this.args.model.save(copiedData);

      this.toasts.success({
        data: { message: i18n("discourse_ai.tools.saved") },
        duration: "short",
      });

      if (
        !this.args.tools.content.some((tool) => tool.id === this.args.model.id)
      ) {
        this.args.tools.content.push(this.args.model);
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
        removeValueFromArray(this.args.tools.content, this.args.model);
        this.router.transitionTo("adminPlugins.show.discourse-ai-tools.index");
      },
    });
  }

  @action
  updateUploads(addItemToCollection, uploads) {
    // FormKit uses Immer proxies which cause issues when passed to upload handlers.
    // Convert to plain objects to ensure compatibility.
    const plainUploads = toPlainObject(uploads);
    const uniqueUploads = plainUploads.filter(
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
    // FormKit uses Immer proxies which cause issues when passed to upload handlers.
    // Convert to plain objects to ensure compatibility.
    const plainUploads =
      this.uploadedFiles.length > 0 ? toPlainObject(this.uploadedFiles) : [];
    form.set("rag_uploads", plainUploads);
  }

  @action
  openTestModal(data) {
    const toolData = this.cleanFormData(data);

    this.modal.show(AiToolTestModal, {
      model: {
        toolId: this.args.editingModel.id,
        toolData,
      },
    });
  }

  currentParameterSelection(data, index) {
    return data.parameters[index].type;
  }

  @action
  exportTool() {
    const exportUrl = `/admin/plugins/discourse-ai/ai-tools/${this.args.model.id}/export.json`;
    window.location.href = getURL(exportUrl);
  }

  <template>
    <Form
      class="ai-tool-editor"
      @data={{this.formData}}
      @onSubmit={{this.save}}
      as |form data|
    >
      {{! NAME }}
      <form.Field
        @format="large"
        @name="name"
        @title={{i18n "discourse_ai.tools.name"}}
        @tooltip={{i18n "discourse_ai.tools.name_help"}}
        @type="input"
        @validation="required|length:1,100"
        as |field|
      >
        <field.Control class="ai-tool-editor__name" />
      </form.Field>

      {{! TOOL NAME }}
      <form.Field
        @format="large"
        @name="tool_name"
        @title={{i18n "discourse_ai.tools.tool_name"}}
        @tooltip={{i18n "discourse_ai.tools.tool_name_help"}}
        @type="input"
        @validation="required|length:1,100"
        as |field|
      >
        <field.Control class="ai-tool-editor__tool_name" />
      </form.Field>

      {{! DESCRIPTION }}
      <form.Field
        @format="full"
        @name="description"
        @title={{i18n "discourse_ai.tools.description"}}
        @tooltip={{i18n "discourse_ai.tools.description_help"}}
        @type="textarea"
        @validation="required|length:1,1000"
        as |field|
      >
        <field.Control
          class="ai-tool-editor__description"
          placeholder={{i18n "discourse_ai.tools.description_help"}}
          @height={{60}}
        />
      </form.Field>

      {{! SUMMARY }}
      <form.Field
        @format="large"
        @name="summary"
        @title={{i18n "discourse_ai.tools.summary"}}
        @tooltip={{i18n "discourse_ai.tools.summary_help"}}
        @type="input"
        @validation="required|length:1,255"
        as |field|
      >
        <field.Control class="ai-tool-editor__summary" />
      </form.Field>

      {{! PARAMETERS }}
      <form.Collection @name="parameters" as |collection index collectionData|>
        <form.Container class="ai-tool-parameter">
          <form.Row as |row|>
            <row.Col @size={{6}}>
              <collection.Field
                @format="full"
                @name="name"
                @title={{i18n "discourse_ai.tools.parameter_name"}}
                @type="input"
                @validation="required|length:1,100"
                as |field|
              >
                <field.Control />
              </collection.Field>
            </row.Col>

            <row.Col @size={{6}}>
              <collection.Field
                @format="full"
                @name="type"
                @title={{i18n "discourse_ai.tools.parameter_type"}}
                @type="select"
                @validation="required"
                as |field|
              >
                <field.Control as |select|>
                  {{#each this.PARAMETER_TYPES as |type|}}
                    <select.Option
                      @value={{type.id}}
                    >{{type.name}}</select.Option>
                  {{/each}}
                </field.Control>
              </collection.Field>
            </row.Col>

            {{#if (eq collectionData.type "array")}}
              <row.Col @size={{6}}>
                <collection.Field
                  @format="full"
                  @name="item_type"
                  @title={{i18n "discourse_ai.tools.parameter_item_type"}}
                  @type="select"
                  as |field|
                >
                  <field.Control as |select|>
                    {{#each this.ITEM_TYPES as |type|}}
                      <select.Option
                        @value={{type.id}}
                      >{{type.name}}</select.Option>
                    {{/each}}
                  </field.Control>
                </collection.Field>
              </row.Col>
            {{/if}}
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{12}}>
              <collection.Field
                @format="full"
                @name="description"
                @title={{i18n "discourse_ai.tools.parameter_description"}}
                @type="input"
                @validation="required|length:1,1000"
                as |field|
              >
                <field.Control class="ai-tool-editor__parameter-description" />
              </collection.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col>
              <collection.Field
                @name="required"
                @title={{i18n "discourse_ai.tools.parameter_required"}}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </collection.Field>
            </row.Col>

            <row.Col>
              <collection.Field
                @name="isEnum"
                @onSet={{this.toggleIsEnum}}
                @title={{i18n "discourse_ai.tools.parameter_enum"}}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </collection.Field>
            </row.Col>

            {{#if collectionData.isEnum}}
              <row.Col @size={{8}}>
                <collection.Collection @name="enum" as |child childIndex|>
                  <form.Container class="ai-tool-parameter__enum-values">
                    <child.Field
                      @title={{i18n "discourse_ai.tools.enum_value"}}
                      @type="input"
                      @validation="required"
                      as |field|
                    >
                      <field.Control />

                      {{#if
                        (and
                          (gt collectionData.enum.length 1) (gt childIndex 0)
                        )
                      }}
                        <form.Button
                          class="btn-danger"
                          @action={{fn child.remove childIndex}}
                          @icon="trash-can"
                        />
                      {{/if}}
                    </child.Field>
                  </form.Container>
                </collection.Collection>
              </row.Col>

              <row.Col @size={{8}}>
                <form.Button
                  @action={{fn
                    form.addItemToCollection
                    (concat "parameters." index ".enum")
                    ""
                  }}
                  @icon="plus"
                  @label="discourse_ai.tools.add_enum_value"
                />
              </row.Col>
            {{/if}}
          </form.Row>
          <form.Row as |row|>
            <row.Col class="ai-tool-parameter-actions">
              <form.Button
                class="btn-danger"
                @action={{fn collection.remove index}}
                @icon="trash-can"
                @label="discourse_ai.tools.remove_parameter"
              />
            </row.Col>
          </form.Row>
        </form.Container>
      </form.Collection>

      <form.Button
        class="btn-default"
        @action={{fn
          form.addItemToCollection
          "parameters"
          (hash
            name="" type="string" description="" required=false isEnum=false
          )
        }}
        @icon="plus"
        @label="discourse_ai.tools.add_parameter"
      />

      {{! CREDENTIAL CONTRACTS }}
      <form.Collection @name="secret_contracts" as |collection index|>
        <form.Container class="ai-tool-secret-contract">
          <form.Row as |row|>
            <row.Col @size={{6}}>
              <collection.Field
                @format="full"
                @name="alias"
                @title={{i18n "discourse_ai.tools.secret_alias"}}
                @tooltip={{i18n "discourse_ai.tools.secret_alias_help"}}
                @type="input"
                @validation="required|length:1,100"
                as |field|
              >
                <field.Control />
              </collection.Field>
            </row.Col>

            <row.Col @size={{6}}>
              <collection.Field
                @format="full"
                @name="ai_secret_id"
                @title={{i18n "discourse_ai.tools.secret_credential"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <AiSecretSelector
                    @onChange={{field.set}}
                    @secrets={{this.secretOptions}}
                    @value={{field.value}}
                  />
                </field.Control>
              </collection.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col class="ai-tool-secret-contract__actions">
              <form.Button
                class="btn-danger"
                @action={{fn collection.remove index}}
                @icon="trash-can"
                @label="discourse_ai.tools.remove_secret_contract"
              />
            </row.Col>
          </form.Row>
        </form.Container>
      </form.Collection>

      <form.Button
        class="btn-default"
        @action={{fn
          form.addItemToCollection
          "secret_contracts"
          (hash alias="" ai_secret_id=null)
        }}
        @icon="plus"
        @label="discourse_ai.tools.add_secret_contract"
      />

      {{! SCRIPT }}
      <form.Field
        @format="full"
        @name="script"
        @title={{i18n "discourse_ai.tools.script"}}
        @type="code"
        @validation="required|length:1,100000"
        as |field|
      >
        <field.Control @height={{600}} @lang="javascript" />
      </form.Field>

      {{! UPLOADS }}
      {{#if this.siteSettings.ai_embeddings_enabled}}
        <form.Field
          @format="full"
          @name="rag_uploads"
          @title={{i18n "discourse_ai.rag.uploads.title"}}
          @tooltip={{this.ragUploadsDescription}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <RagUploader
              @allowImages={{@settings.rag_images_enabled}}
              @onRemove={{fn this.removeUpload form}}
              @target={{@editingModel}}
              @updateUploads={{fn this.updateUploads form.addItemToCollection}}
            />
            <RagOptionsFk
              @allowImages={{@settings.rag_images_enabled}}
              @data={{data}}
              @form={{form}}
              @llms={{@llms}}
            />
          </field.Control>
        </form.Field>
      {{/if}}

      <form.Actions>
        <form.Submit
          class="ai-tool-editor__save"
          @label="discourse_ai.tools.save"
        />

        {{#unless @isNew}}
          <form.Button
            class="btn-default ai-tool-editor__test-button"
            @action={{fn this.openTestModal data}}
            @label="discourse_ai.tools.test"
          />
          <form.Button
            class="btn-default ai-tool-editor__export"
            @action={{this.exportTool}}
            @label="discourse_ai.tools.export"
          />
          <form.Button
            class="btn-danger ai-tool-editor__delete"
            @action={{this.delete}}
            @icon="trash-can"
            @label="discourse_ai.tools.delete"
          />
        {{/unless}}
      </form.Actions>
    </Form>
  </template>
}
