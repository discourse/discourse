import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { gt, or } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import Avatar from "discourse/helpers/bound-avatar-template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";
import GroupChooser from "select-kit/components/group-chooser";
import AiPersonaResponseFormatEditor from "../components/modal/ai-persona-response-format-editor";
import AiLlmSelector from "./ai-llm-selector";
import AiPersonaCollapsableExample from "./ai-persona-example";
import AiPersonaToolOptions from "./ai-persona-tool-options";
import AiToolSelector from "./ai-tool-selector";
import RagOptionsFk from "./rag-options-fk";
import RagUploader from "./rag-uploader";

export default class PersonaEditor extends Component {
  @service router;
  @service dialog;
  @service toasts;
  @service siteSettings;

  @tracked allGroups = [];
  @tracked isSaving = false;

  dirtyFormData = null;

  @cached
  get formData() {
    // This is to recover a dirty state after persisting a single form field.
    // It's meant to be consumed only once.
    if (this.dirtyFormData) {
      const data = this.dirtyFormData;
      this.dirtyFormData = null;
      return data;
    } else {
      const data = this.args.model.toPOJO();

      if (data.tools) {
        data.toolOptions = this.mapToolOptions(data.toolOptions, data.tools);
      }

      return data;
    }
  }

  get chatPluginEnabled() {
    return this.siteSettings.chat_enabled;
  }

  get allTools() {
    return this.args.personas.resultSetMeta.tools;
  }

  get maxPixelValues() {
    const l = (key) =>
      i18n(`discourse_ai.ai_persona.vision_max_pixel_sizes.${key}`);
    return [
      { name: l("low"), id: 65536 },
      { name: l("medium"), id: 262144 },
      { name: l("high"), id: 1048576 },
    ];
  }

  get forcedToolStrategies() {
    const content = [
      {
        id: -1,
        name: i18n("discourse_ai.ai_persona.tool_strategies.all"),
      },
    ];

    [1, 2, 5].forEach((i) => {
      content.push({
        id: i,
        name: i18n("discourse_ai.ai_persona.tool_strategies.replies", {
          count: i,
        }),
      });
    });

    return content;
  }

  @action
  async updateAllGroups() {
    const groups = await Group.findAll({ include_everyone: true });

    // Backwards-compatibility code. TODO(roman): Remove 01-09-2025
    const hasEveryoneGroup = groups.find((g) => g.id === 0);
    if (!hasEveryoneGroup) {
      const everyoneGroupName = "everyone";
      groups.push({ id: 0, name: everyoneGroupName });
    }

    this.allGroups = groups;
  }

  @action
  async save(data) {
    const isNew = this.args.model.isNew;
    this.isSaving = true;

    try {
      const personaToSave = Object.assign(
        this.args.model,
        this.args.model.fromPOJO(data)
      );

      await personaToSave.save();
      this.#sortPersonas();

      if (isNew && this.args.model.rag_uploads.length === 0) {
        this.args.personas.addObject(personaToSave);
        await this.router.replaceWith(
          "adminPlugins.show.discourse-ai-personas.edit",
          personaToSave
        );
      }
      this.toasts.success({
        data: { message: i18n("discourse_ai.ai_persona.saved") },
        duration: "short",
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  get adminUser() {
    // Work around user not being extensible.
    const userClone = Object.assign({}, this.args.model?.user);

    return AdminUser.create(userClone);
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.ai_persona.confirm_delete"),
      didConfirm: () => {
        return this.args.model.destroyRecord().then(() => {
          this.args.personas.removeObject(this.args.model);
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai-personas.index"
          );
        });
      },
    });
  }

  @action
  async toggleEnabled(dirtyData, value, { set }) {
    set("enabled", value);
    await this.persistField(dirtyData, "enabled", value);
  }

  @action
  async togglePriority(dirtyData, value, { set }) {
    set("priority", value);
    await this.persistField(dirtyData, "priority", value, true);
  }

  @action
  async createUser(form) {
    try {
      let user = await this.args.model.createUser();
      form.set("user", user);
      form.set("user_id", user.id);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  updateUploads(form, newUploads) {
    form.set("rag_uploads", newUploads);
  }

  @action
  async removeUpload(form, dirtyData, currentUploads, upload) {
    const updatedUploads = currentUploads.filter(
      (file) => file.id !== upload.id
    );

    form.set("rag_uploads", updatedUploads);

    if (!this.args.model.isNew) {
      await this.persistField(dirtyData, "rag_uploads", updatedUploads);
    }
  }

  @action
  updateToolNames(form, currentData, updatedTools) {
    const removedTools =
      currentData?.tools?.filter((ct) => !updatedTools.includes(ct)) || [];
    const updatedOptions = this.mapToolOptions(
      currentData.toolOptions,
      updatedTools
    );

    form.setProperties({
      tools: updatedTools,
      toolOptions: updatedOptions,
    });

    if (currentData.forcedTools?.length > 0) {
      const updatedForcedTools = currentData.forcedTools.filter(
        (fct) => !removedTools.includes(fct)
      );
      form.set("forcedTools", updatedForcedTools);
    }
  }

  @action
  availableForcedTools(tools) {
    return this.allTools.filter((tool) => tools.includes(tool.id));
  }

  @action
  addExamplesPair(form, data) {
    const newExamples = [...data.examples, ["", ""]];
    form.set("examples", newExamples);
  }

  mapToolOptions(currentOptions, toolNames) {
    const updatedOptions = Object.assign({}, currentOptions);

    toolNames.forEach((toolId) => {
      const tool = this.allTools.find((item) => item.id === toolId);
      const toolOptions = tool?.options;

      if (!toolOptions || updatedOptions[toolId]) {
        return;
      }

      const mappedOptions = {};
      Object.keys(toolOptions).forEach((key) => {
        mappedOptions[key] = null;
      });

      updatedOptions[toolId] = mappedOptions;
    });

    return updatedOptions;
  }

  async persistField(dirtyData, field, newValue, sortPersonas) {
    if (!this.args.model.isNew) {
      const updatedDirtyData = Object.assign({}, dirtyData);
      updatedDirtyData[field] = newValue;

      try {
        const args = {};
        args[field] = newValue;

        this.dirtyFormData = updatedDirtyData;
        await this.args.model.update(args);
        if (sortPersonas) {
          this.#sortPersonas();
        }
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  #sortPersonas() {
    const sorted = this.args.personas.toArray().sort((a, b) => {
      if (a.priority && !b.priority) {
        return -1;
      } else if (!a.priority && b.priority) {
        return 1;
      } else {
        return a.name.localeCompare(b.name);
      }
    });
    this.args.personas.clear();
    this.args.personas.setObjects(sorted);
  }

  @action
  exportPersona() {
    const exportUrl = `/admin/plugins/discourse-ai/ai-personas/${this.args.model.id}/export.json`;
    window.location.href = getURL(exportUrl);
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-personas"
      @label="discourse_ai.ai_persona.back"
    />
    <div class="ai-persona-editor" {{didInsert this.updateAllGroups @model.id}}>
      <Form @onSubmit={{this.save}} @data={{this.formData}} as |form data|>
        <form.Field
          @name="name"
          @title={{i18n "discourse_ai.ai_persona.name"}}
          @validation="required|length:1,100"
          @disabled={{data.system}}
          @format="large"
          as |field|
        >
          <field.Input />
        </form.Field>

        <form.Field
          @name="description"
          @title={{i18n "discourse_ai.ai_persona.description"}}
          @validation="required|length:1,100"
          @disabled={{data.system}}
          @format="large"
          as |field|
        >
          <field.Textarea />
        </form.Field>

        <form.Field
          @name="system_prompt"
          @title={{i18n "discourse_ai.ai_persona.system_prompt"}}
          @validation="required|length:1,100000"
          @disabled={{data.system}}
          @format="large"
          as |field|
        >
          <field.Textarea />
        </form.Field>

        <AiPersonaResponseFormatEditor @form={{form}} @data={{data}} />

        <form.Field
          @name="default_llm_id"
          @title={{i18n "discourse_ai.ai_persona.default_llm"}}
          @tooltip={{i18n "discourse_ai.ai_persona.default_llm_help"}}
          @format="large"
          as |field|
        >
          <field.Custom>
            <AiLlmSelector
              @value={{field.value}}
              @llms={{@personas.resultSetMeta.llms}}
              @onChange={{field.set}}
              @class="ai-persona-editor__llms"
            />
          </field.Custom>
        </form.Field>

        <form.Field
          @name="allowed_group_ids"
          @title={{i18n "discourse_ai.ai_persona.allowed_groups"}}
          @format="large"
          as |field|
        >
          <field.Custom>
            <GroupChooser
              @value={{data.allowed_group_ids}}
              @content={{this.allGroups}}
              @onChange={{field.set}}
            />
          </field.Custom>
        </form.Field>

        <form.Field
          @name="vision_enabled"
          @title={{i18n "discourse_ai.ai_persona.vision_enabled"}}
          @tooltip={{i18n "discourse_ai.ai_persona.vision_enabled_help"}}
          @format="large"
          as |field|
        >
          <field.Checkbox />
        </form.Field>

        {{#if data.vision_enabled}}
          <form.Field
            @name="vision_max_pixels"
            @title={{i18n "discourse_ai.ai_persona.vision_max_pixels"}}
            @onSet={{this.onChangeMaxPixels}}
            @format="large"
            as |field|
          >
            <field.Select @includeNone={{false}} as |select|>
              {{#each this.maxPixelValues as |pixelValue|}}
                <select.Option
                  @value={{pixelValue.id}}
                >{{pixelValue.name}}</select.Option>
              {{/each}}
            </field.Select>
          </form.Field>
        {{/if}}

        <form.Field
          @name="max_context_posts"
          @title={{i18n "discourse_ai.ai_persona.max_context_posts"}}
          @tooltip={{i18n "discourse_ai.ai_persona.max_context_posts_help"}}
          @format="large"
          as |field|
        >
          <field.Input @type="number" lang="en" />
        </form.Field>

        {{#unless data.system}}
          <form.Field
            @name="temperature"
            @title={{i18n "discourse_ai.ai_persona.temperature"}}
            @tooltip={{i18n "discourse_ai.ai_persona.temperature_help"}}
            @disabled={{data.system}}
            @format="large"
            as |field|
          >
            <field.Input @type="number" step="any" lang="en" />
          </form.Field>

          <form.Field
            @name="top_p"
            @title={{i18n "discourse_ai.ai_persona.top_p"}}
            @tooltip={{i18n "discourse_ai.ai_persona.top_p_help"}}
            @disabled={{data.system}}
            @format="large"
            as |field|
          >
            <field.Input @type="number" step="any" lang="en" />
          </form.Field>
        {{/unless}}

        <form.Section
          @title={{i18n "discourse_ai.ai_persona.examples.title"}}
          @subtitle={{i18n "discourse_ai.ai_persona.examples.examples_help"}}
        >
          {{#unless data.system}}
            <form.Container>
              <form.Button
                @action={{fn this.addExamplesPair form data}}
                @label="discourse_ai.ai_persona.examples.new"
                class="ai-persona-editor__new_example"
              />
            </form.Container>
          {{/unless}}

          {{#if (gt data.examples.length 0)}}
            <form.Collection @name="examples" as |exCollection exCollectionIdx|>
              <AiPersonaCollapsableExample
                @examplesCollection={{exCollection}}
                @exampleNumber={{exCollectionIdx}}
                @system={{data.system}}
                @form={{form}}
              />
            </form.Collection>
          {{/if}}
        </form.Section>

        <form.Section @title={{i18n "discourse_ai.ai_persona.ai_tools"}}>
          <form.Field
            @name="tools"
            @title={{i18n "discourse_ai.ai_persona.tools"}}
            @format="large"
            as |field|
          >
            <field.Custom>
              <AiToolSelector
                @value={{field.value}}
                @disabled={{data.system}}
                @onChange={{fn this.updateToolNames form data}}
                @content={{@personas.resultSetMeta.tools}}
              />
            </field.Custom>
          </form.Field>

          {{#if (gt data.tools.length 0)}}
            <form.Field
              @name="forcedTools"
              @title={{i18n "discourse_ai.ai_persona.forced_tools"}}
              @format="large"
              as |field|
            >
              <field.Custom>
                <AiToolSelector
                  @value={{field.value}}
                  @disabled={{data.system}}
                  @onChange={{field.set}}
                  @content={{this.availableForcedTools data.tools}}
                />
              </field.Custom>
            </form.Field>
          {{/if}}

          {{#if (gt data.forcedTools.length 0)}}
            <form.Field
              @name="forced_tool_count"
              @title={{i18n "discourse_ai.ai_persona.forced_tool_strategy"}}
              @format="large"
              as |field|
            >
              <field.Select @includeNone={{false}} as |select|>
                {{#each this.forcedToolStrategies as |fts|}}
                  <select.Option @value={{fts.id}}>{{fts.name}}</select.Option>
                {{/each}}
              </field.Select>
            </form.Field>
          {{/if}}

          {{#if (gt data.tools.length 0)}}
            <form.Field
              @name="tool_details"
              @title={{i18n "discourse_ai.ai_persona.tool_details"}}
              @tooltip={{i18n "discourse_ai.ai_persona.tool_details_help"}}
              @format="large"
              as |field|
            >
              <field.Checkbox />
            </form.Field>

            <AiPersonaToolOptions
              @form={{form}}
              @data={{data}}
              @llms={{@personas.resultSetMeta.llms}}
              @allTools={{@personas.resultSetMeta.tools}}
            />
          {{/if}}
        </form.Section>

        {{#if this.siteSettings.ai_embeddings_enabled}}
          <form.Section @title={{i18n "discourse_ai.rag.title"}}>
            <form.Field
              @name="rag_uploads"
              @title={{i18n "discourse_ai.rag.uploads.title"}}
              @format="full"
              as |field|
            >
              <field.Custom>
                <RagUploader
                  @target={{data}}
                  @targetName="AiPersona"
                  @updateUploads={{fn this.updateUploads form}}
                  @onRemove={{fn this.removeUpload form data field.value}}
                  @allowImages={{@personas.resultSetMeta.settings.rag_images_enabled}}
                />
              </field.Custom>
            </form.Field>

            <RagOptionsFk
              @form={{form}}
              @data={{data}}
              @llms={{@personas.resultSetMeta.llms}}
              @allowImages={{@personas.resultSetMeta.settings.rag_images_enabled}}
            >
              <form.Field
                @name="rag_conversation_chunks"
                @title={{i18n
                  "discourse_ai.ai_persona.rag_conversation_chunks"
                }}
                @tooltip={{i18n
                  "discourse_ai.ai_persona.rag_conversation_chunks_help"
                }}
                @format="large"
                as |field|
              >
                <field.Input @type="number" step="any" lang="en" />
              </form.Field>

              <form.Field
                @name="question_consolidator_llm_id"
                @title={{i18n
                  "discourse_ai.ai_persona.question_consolidator_llm"
                }}
                @tooltip={{i18n
                  "discourse_ai.ai_persona.question_consolidator_llm_help"
                }}
                @format="large"
                as |field|
              >
                <field.Custom>
                  <AiLlmSelector
                    @value={{field.value}}
                    @llms={{@personas.resultSetMeta.llms}}
                    @onChange={{field.set}}
                    @class="ai-persona-editor__llms"
                  />
                </field.Custom>
              </form.Field>
            </RagOptionsFk>
          </form.Section>
        {{/if}}

        <form.Section @title={{i18n "discourse_ai.ai_persona.ai_bot.title"}}>
          <form.Field
            @name="enabled"
            @title={{i18n "discourse_ai.ai_persona.enabled"}}
            @onSet={{fn this.toggleEnabled data}}
            as |field|
          >
            <field.Toggle />
          </form.Field>

          <form.Field
            @name="priority"
            @title={{i18n "discourse_ai.ai_persona.priority"}}
            @onSet={{fn this.togglePriority data}}
            @tooltip={{i18n "discourse_ai.ai_persona.priority_help"}}
            as |field|
          >
            <field.Toggle />
          </form.Field>

          {{#if @model.isNew}}
            <div>{{i18n "discourse_ai.ai_persona.ai_bot.save_first"}}</div>
          {{else}}
            {{#if data.default_llm_id}}
              <form.Field
                @name="force_default_llm"
                @title={{i18n "discourse_ai.ai_persona.force_default_llm"}}
                @format="large"
                as |field|
              >
                <field.Checkbox />
              </form.Field>
            {{/if}}

            <form.Container
              @title={{i18n "discourse_ai.ai_persona.user"}}
              @tooltip={{unless
                data.user
                (i18n "discourse_ai.ai_persona.create_user_help")
              }}
              class="ai-persona-editor__ai_bot_user"
            >
              {{#if data.user}}
                <a
                  class="avatar"
                  href={{data.user.path}}
                  data-user-card={{data.user.username}}
                >
                  {{Avatar data.user.avatar_template "small"}}
                </a>
                <LinkTo @route="adminUser" @model={{this.adminUser}}>
                  {{data.user.username}}
                </LinkTo>
              {{else}}
                <form.Button
                  @action={{fn this.createUser form}}
                  @label="discourse_ai.ai_persona.create_user"
                  class="ai-persona-editor__create-user"
                />
              {{/if}}
            </form.Container>

            {{#if data.user}}
              <form.Field
                @name="allow_personal_messages"
                @title={{i18n
                  "discourse_ai.ai_persona.allow_personal_messages"
                }}
                @tooltip={{i18n
                  "discourse_ai.ai_persona.allow_personal_messages_help"
                }}
                @format="large"
                as |field|
              >
                <field.Checkbox />
              </form.Field>

              <form.Field
                @name="allow_topic_mentions"
                @title={{i18n "discourse_ai.ai_persona.allow_topic_mentions"}}
                @tooltip={{i18n
                  "discourse_ai.ai_persona.allow_topic_mentions_help"
                }}
                @format="large"
                as |field|
              >
                <field.Checkbox />
              </form.Field>

              {{#if this.chatPluginEnabled}}
                <form.Field
                  @name="allow_chat_direct_messages"
                  @title={{i18n
                    "discourse_ai.ai_persona.allow_chat_direct_messages"
                  }}
                  @tooltip={{i18n
                    "discourse_ai.ai_persona.allow_chat_direct_messages_help"
                  }}
                  @format="large"
                  as |field|
                >
                  <field.Checkbox />
                </form.Field>

                <form.Field
                  @name="allow_chat_channel_mentions"
                  @title={{i18n
                    "discourse_ai.ai_persona.allow_chat_channel_mentions"
                  }}
                  @tooltip={{i18n
                    "discourse_ai.ai_persona.allow_chat_channel_mentions_help"
                  }}
                  @format="large"
                  as |field|
                >
                  <field.Checkbox />
                </form.Field>
              {{/if}}
            {{/if}}
          {{/if}}
        </form.Section>

        <form.Actions>
          <form.Submit />

          {{#unless (or @model.isNew @model.system)}}
            <form.Button
              @label="discourse_ai.ai_persona.export"
              @action={{this.exportPersona}}
              class="ai-persona-editor__export"
            />
            <form.Button
              @action={{this.delete}}
              @label="discourse_ai.ai_persona.delete"
              class="btn-danger"
            />
          {{/unless}}
        </form.Actions>
      </Form>
    </div>
  </template>
}
