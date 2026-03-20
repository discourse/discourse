/* eslint-disable ember/no-side-effects */
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminUser from "discourse/admin/models/admin-user";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import Avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { AUTO_GROUPS } from "discourse/lib/constants";
import getURL from "discourse/lib/get-url";
import Group from "discourse/models/group";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { and, eq, gt, not, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AiAgentMcpToolSelectorModal from "../components/modal/ai-agent-mcp-tool-selector-modal";
import AiAgentResponseFormatEditor from "../components/modal/ai-agent-response-format-editor";
import { toPlainObject } from "../lib/utilities";
import AiAgentCollapsableExample from "./ai-agent-example";
import AiAgentToolOptions from "./ai-agent-tool-options";
import AiLlmSelector from "./ai-llm-selector";
import AiToolSelector from "./ai-tool-selector";
import RagOptionsFk from "./rag-options-fk";
import RagUploader from "./rag-uploader";

const TOOL_TOKEN_LOW_THRESHOLD = 2000;
const TOOL_TOKEN_HIGH_THRESHOLD = 4000;
const TOOL_TOKEN_BAR_MAX = 6000;
const TOOL_COUNT_WARNING_THRESHOLD = 5;
const TOOL_COUNT_BAR_MAX = 7;

export default class AgentEditor extends Component {
  @service router;
  @service site;
  @service dialog;
  @service modal;
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
    return this.args.agents.resultSetMeta.tools;
  }

  get allMcpServers() {
    return this.args.agents.resultSetMeta.mcp_servers || [];
  }

  get maxPixelValues() {
    const l = (key) =>
      i18n(`discourse_ai.ai_agent.vision_max_pixel_sizes.${key}`);
    return [
      { name: l("low"), id: 65536 },
      { name: l("medium"), id: 262144 },
      { name: l("high"), id: 1048576 },
    ];
  }

  get executionModes() {
    return [
      {
        id: "default",
        name: i18n("discourse_ai.ai_agent.execution_mode_options.default"),
      },
      {
        id: "agentic",
        name: i18n("discourse_ai.ai_agent.execution_mode_options.agentic"),
      },
    ];
  }

  get forcedToolStrategies() {
    const content = [
      {
        id: -1,
        name: i18n("discourse_ai.ai_agent.tool_strategies.all"),
      },
    ];

    [1, 2, 5].forEach((i) => {
      content.push({
        id: i,
        name: i18n("discourse_ai.ai_agent.tool_strategies.replies", {
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
    const hasEveryoneGroup = groups.find(
      (g) => g.id === AUTO_GROUPS.everyone.id
    );
    if (!hasEveryoneGroup) {
      groups.push(this.site.groupsById[AUTO_GROUPS.everyone.id]);
    }

    this.allGroups = groups;
  }

  @action
  async save(data) {
    const isNew = this.args.model.isNew;
    this.isSaving = true;

    try {
      const agentToSave = Object.assign(
        this.args.model,
        this.args.model.fromPOJO(data)
      );

      await agentToSave.save();
      this.#sortAgents();

      if (isNew && this.args.model.rag_uploads.length === 0) {
        addUniqueValueToArray(this.args.agents.content, agentToSave);
        await this.router.replaceWith(
          "adminPlugins.show.discourse-ai-agents.edit",
          agentToSave
        );
      }
      this.toasts.success({
        data: { message: i18n("discourse_ai.ai_agent.saved") },
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
      message: i18n("discourse_ai.ai_agent.confirm_delete"),
      didConfirm: () => {
        return this.args.model.destroyRecord().then(() => {
          removeValueFromArray(this.args.agents.content, this.args.model);
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai-agents.index"
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
    // FormKit uses Immer proxies which cause issues when passed to upload handlers.
    // Convert to plain objects to ensure compatibility.
    const plainUploads = toPlainObject(newUploads);
    form.set("rag_uploads", plainUploads);
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
  onExecutionModeChange(mode, { set }) {
    set("execution_mode", mode);
    if (mode === "default") {
      set("max_turn_tokens", null);
      set("compression_threshold", null);
    } else {
      set("compression_threshold", 80);
    }
  }

  @action
  availableForcedTools(tools) {
    return this.allTools.filter((tool) => tools.includes(tool.id));
  }

  mcpServerById(serverId) {
    return this.allMcpServers.find((item) => item.id === serverId);
  }

  selectedMcpToolNames(serverId, mcpServerToolNames = {}) {
    // Draft form state may use numeric keys, while persisted JSON keys are strings.
    return mcpServerToolNames[serverId] || mcpServerToolNames[`${serverId}`];
  }

  selectedMcpTools(serverId, mcpServerToolNames = {}) {
    const server = this.mcpServerById(serverId);
    const tools = server?.tools || [];
    const selectedToolNames = this.selectedMcpToolNames(
      serverId,
      mcpServerToolNames
    );

    if (!selectedToolNames?.length) {
      return tools;
    }

    const selectedToolSet = new Set(selectedToolNames);
    return tools.filter((tool) => selectedToolSet.has(tool.name));
  }

  @action
  selectedToolsWithTokens(tools) {
    return tools.map((toolId) => {
      const tool = this.allTools.find((t) => t.id === toolId);
      return {
        id: toolId,
        name: tool?.name || toolId,
        tokenCount: tool?.token_count || 0,
      };
    });
  }

  @action
  selectedMcpServers(serverIds, mcpServerToolNames = {}) {
    return (serverIds || []).map((serverId) => {
      const server = this.mcpServerById(serverId);
      const tools = server?.tools || [];
      const selectedTools = this.selectedMcpTools(serverId, mcpServerToolNames);

      return {
        id: serverId,
        name: server?.name || serverId,
        toolCount: server?.tool_count || 0,
        tokenCount: server?.token_count || 0,
        selectedToolCount: selectedTools.length,
        selectedTokenCount: selectedTools.reduce(
          (sum, tool) => sum + (tool.token_count || 0),
          0
        ),
        allToolsEnabled: !this.selectedMcpToolNames(
          serverId,
          mcpServerToolNames
        )?.length,
        tools,
        lastHealthStatus: server?.last_health_status,
      };
    });
  }

  @action
  totalToolTokens(selectedTools = []) {
    return selectedTools.reduce((sum, tool) => {
      return sum + (tool?.tokenCount || 0);
    }, 0);
  }

  @action
  totalMcpToolTokens(selectedMcpServers = []) {
    return selectedMcpServers.reduce(
      (sum, server) => sum + server.selectedTokenCount,
      0
    );
  }

  @action
  totalSelectedToolTokens(selectedTools = [], selectedMcpServers = []) {
    return (
      this.totalToolTokens(selectedTools) +
      this.totalMcpToolTokens(selectedMcpServers)
    );
  }

  @action
  totalSelectedToolCount(selectedTools = [], selectedMcpServers = []) {
    const mcpToolCount = selectedMcpServers.reduce(
      (sum, server) => sum + server.selectedToolCount,
      0
    );

    return selectedTools.length + mcpToolCount;
  }

  @action
  toolTokenIndicatorStyle(total) {
    const percent = Math.min(100, (total / TOOL_TOKEN_BAR_MAX) * 100);
    return trustHTML(`left: ${percent}%`);
  }

  @action
  toolCountIndicatorStyle(count) {
    const percent = Math.min(100, (count / TOOL_COUNT_BAR_MAX) * 100);
    return trustHTML(`left: ${percent}%`);
  }

  @action
  toolTokenSeverity(total, count) {
    if (
      total >= TOOL_TOKEN_HIGH_THRESHOLD ||
      count >= TOOL_COUNT_WARNING_THRESHOLD
    ) {
      return "high";
    } else if (total >= TOOL_TOKEN_LOW_THRESHOLD) {
      return "medium";
    }
    return "low";
  }

  @action
  toolTokenOnlySeverity(total) {
    if (total >= TOOL_TOKEN_HIGH_THRESHOLD) {
      return "high";
    } else if (total >= TOOL_TOKEN_LOW_THRESHOLD) {
      return "medium";
    }
    return "low";
  }

  @action
  toolCountOnlySeverity(count) {
    return count >= TOOL_COUNT_WARNING_THRESHOLD ? "high" : "low";
  }

  @action
  showExamples(data) {
    return data.examples?.length > 0 || !data.system;
  }

  @action
  tooManyTools(count) {
    return count >= TOOL_COUNT_WARNING_THRESHOLD;
  }

  @action
  highTokenUsage(total) {
    return total >= TOOL_TOKEN_HIGH_THRESHOLD;
  }

  @action
  addExamplesPair(form, data) {
    const newExamples = [...data.examples, ["", ""]];
    form.set("examples", newExamples);
  }

  @action
  updateMcpServerIds(form, currentData, updatedServerIds) {
    const normalizedToolNames = {};

    Object.entries(currentData.mcp_server_tool_names || {}).forEach(
      ([serverId, toolNames]) => {
        const normalizedServerId = Number(serverId);
        if (updatedServerIds.includes(normalizedServerId)) {
          normalizedToolNames[normalizedServerId] = toolNames;
        }
      }
    );

    form.setProperties({
      mcp_server_ids: updatedServerIds,
      mcp_server_tool_names: normalizedToolNames,
    });
  }

  @action
  openMcpToolSelector(form, currentData, server) {
    this.modal.show(AiAgentMcpToolSelectorModal, {
      model: {
        serverName: server.name,
        tools: server.tools || [],
        selectedToolNames: this.selectedMcpToolNames(
          server.id,
          currentData.mcp_server_tool_names || {}
        ),
        onSave: (selectedToolNames) => {
          const updatedToolNames = {
            ...(currentData.mcp_server_tool_names || {}),
          };
          let updatedServerIds = [...(currentData.mcp_server_ids || [])];

          if (selectedToolNames?.length) {
            updatedToolNames[server.id] = selectedToolNames;
          } else {
            delete updatedToolNames[server.id];
          }

          if (selectedToolNames?.length === 0) {
            updatedServerIds = updatedServerIds.filter(
              (id) => id !== server.id
            );
          } else if (!updatedServerIds.includes(server.id)) {
            updatedServerIds = [...updatedServerIds, server.id];
          }

          form.setProperties({
            mcp_server_ids: updatedServerIds,
            mcp_server_tool_names: updatedToolNames,
          });
        },
      },
    });
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

  async persistField(dirtyData, field, newValue, sortAgents) {
    if (!this.args.model.isNew) {
      const updatedDirtyData = Object.assign({}, dirtyData);
      updatedDirtyData[field] = newValue;

      try {
        const args = {};
        args[field] = newValue;

        this.dirtyFormData = updatedDirtyData;
        await this.args.model.update(args);
        if (sortAgents) {
          this.#sortAgents();
        }
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  #sortAgents() {
    // .sort is done in place and agents.content is a tracked array.
    this.args.agents.content.sort((a, b) => {
      if (a.priority && !b.priority) {
        return -1;
      } else if (!a.priority && b.priority) {
        return 1;
      } else {
        return a.name.localeCompare(b.name);
      }
    });
  }

  @action
  exportAgent() {
    const exportUrl = `/admin/plugins/discourse-ai/ai-agents/${this.args.model.id}/export.json`;
    window.location.href = getURL(exportUrl);
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-agents"
      @label="discourse_ai.ai_agent.back"
    />
    <div class="ai-agent-editor" {{didInsert this.updateAllGroups @model.id}}>
      <Form @onSubmit={{this.save}} @data={{this.formData}} as |form data|>
        <form.Field
          @name="name"
          @title={{i18n "discourse_ai.ai_agent.name"}}
          @validation="required|length:1,100"
          @disabled={{data.system}}
          @format="large"
          @type="input"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="description"
          @title={{i18n "discourse_ai.ai_agent.description"}}
          @validation="required|length:1,100"
          @disabled={{data.system}}
          @format="large"
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="system_prompt"
          @title={{i18n "discourse_ai.ai_agent.system_prompt"}}
          @validation="required|length:1,100000"
          @disabled={{data.system}}
          @format="large"
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>

        <AiAgentResponseFormatEditor @form={{form}} @data={{data}} />

        <form.Field
          @name="default_llm_id"
          @title={{i18n "discourse_ai.ai_agent.default_llm"}}
          @tooltip={{i18n "discourse_ai.ai_agent.default_llm_help"}}
          @format="large"
          @type="custom"
          as |field|
        >
          <field.Control>
            <AiLlmSelector
              @value={{field.value}}
              @llms={{@agents.resultSetMeta.llms}}
              @onChange={{field.set}}
              class="ai-agent-editor__llms"
            />
          </field.Control>
        </form.Field>

        <form.Field
          @name="allowed_group_ids"
          @title={{i18n "discourse_ai.ai_agent.allowed_groups"}}
          @format="large"
          @type="custom"
          as |field|
        >
          <field.Control>
            <GroupChooser
              @value={{data.allowed_group_ids}}
              @content={{this.allGroups}}
              @onChange={{field.set}}
            />
          </field.Control>
        </form.Field>

        <form.Field
          @name="vision_enabled"
          @title={{i18n "discourse_ai.ai_agent.vision_enabled"}}
          @tooltip={{i18n "discourse_ai.ai_agent.vision_enabled_help"}}
          @showTitle={{false}}
          @format="large"
          @type="checkbox"
          as |field|
        >
          <field.Control />
        </form.Field>

        {{#if data.vision_enabled}}
          <form.Field
            @name="vision_max_pixels"
            @title={{i18n "discourse_ai.ai_agent.vision_max_pixels"}}
            @onSet={{this.onChangeMaxPixels}}
            @format="large"
            @type="select"
            as |field|
          >
            <field.Control @includeNone={{false}} as |select|>
              {{#each this.maxPixelValues as |pixelValue|}}
                <select.Option
                  @value={{pixelValue.id}}
                >{{pixelValue.name}}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>
        {{/if}}

        {{#if
          (and
            (not data.system) this.siteSettings.ai_llm_temperature_top_p_enabled
          )
        }}
          <form.Field
            @name="temperature"
            @title={{i18n "discourse_ai.ai_agent.temperature"}}
            @tooltip={{i18n "discourse_ai.ai_agent.temperature_help"}}
            @disabled={{data.system}}
            @format="large"
            @type="input-number"
            as |field|
          >
            <field.Control step="any" lang="en" />
          </form.Field>

          <form.Field
            @name="top_p"
            @title={{i18n "discourse_ai.ai_agent.top_p"}}
            @tooltip={{i18n "discourse_ai.ai_agent.top_p_help"}}
            @disabled={{data.system}}
            @format="large"
            @type="input-number"
            as |field|
          >
            <field.Control step="any" lang="en" />
          </form.Field>
        {{/if}}

        {{#if (this.showExamples data)}}
          <form.Section
            @title={{i18n "discourse_ai.ai_agent.examples.title"}}
            @subtitle={{i18n "discourse_ai.ai_agent.examples.examples_help"}}
          >
            {{#unless data.system}}
              <form.Container>
                <form.Button
                  @action={{fn this.addExamplesPair form data}}
                  @label="discourse_ai.ai_agent.examples.new"
                  class="btn-default ai-agent-editor__new_example"
                />
              </form.Container>
            {{/unless}}

            {{#if (gt data.examples.length 0)}}
              <form.Collection
                @name="examples"
                as |exCollection exCollectionIdx|
              >
                <AiAgentCollapsableExample
                  @examplesCollection={{exCollection}}
                  @exampleNumber={{exCollectionIdx}}
                  @system={{data.system}}
                  @form={{form}}
                />
              </form.Collection>
            {{/if}}
          </form.Section>
        {{/if}}

        <form.Section @title={{i18n "discourse_ai.ai_agent.ai_tools"}}>
          <form.Field
            @name="tools"
            @title={{i18n "discourse_ai.ai_agent.tools"}}
            @format="large"
            @type="custom"
            as |field|
          >
            <field.Control>
              <AiToolSelector
                @value={{field.value}}
                @disabled={{data.system}}
                @onChange={{fn this.updateToolNames form data}}
                @content={{@agents.resultSetMeta.tools}}
              />
            </field.Control>
          </form.Field>

          {{#if this.allMcpServers.length}}
            <form.Field
              @name="mcp_server_ids"
              @title={{i18n "discourse_ai.ai_agent.mcp_servers"}}
              @format="large"
              @type="custom"
              as |field|
            >
              <field.Control>
                <AiToolSelector
                  @value={{field.value}}
                  @disabled={{data.system}}
                  @onChange={{fn this.updateMcpServerIds form data}}
                  @content={{this.allMcpServers}}
                />
              </field.Control>
            </form.Field>

            <p class="ai-agent-editor__mcp-server-help">
              {{i18n "discourse_ai.ai_agent.mcp_server_tools_help"}}
            </p>
          {{/if}}

          {{#let
            (this.selectedMcpServers
              data.mcp_server_ids data.mcp_server_tool_names
            )
            (this.selectedToolsWithTokens data.tools)
            as |selectedMcpServers selectedTools|
          }}
            {{#if data.mcp_server_ids.length}}
              <div class="ai-agent-editor__mcp-server-summary">
                {{#each selectedMcpServers as |server|}}
                  <div class="ai-agent-editor__mcp-server-item">
                    <div class="ai-agent-editor__mcp-server-item-main">
                      <span class="ai-agent-editor__mcp-server-name">
                        {{server.name}}
                      </span>
                      <div class="ai-agent-editor__mcp-server-meta">
                        <span>
                          {{#if server.allToolsEnabled}}
                            {{i18n
                              "discourse_ai.ai_agent.mcp_server_enabled_tool_count"
                              count=server.selectedToolCount
                            }}
                          {{else}}
                            {{i18n
                              "discourse_ai.ai_agent.mcp_server_enabled_tools"
                              count=server.selectedToolCount
                              total=server.toolCount
                            }}
                          {{/if}}
                        </span>
                        <span>
                          {{i18n
                            "discourse_ai.ai_agent.mcp_server_tokens_only"
                            tokens=server.selectedTokenCount
                          }}
                        </span>
                        <span
                          class="ai-agent-editor__mcp-server-health
                            {{if
                              (eq server.lastHealthStatus 'healthy')
                              '--healthy'
                              '--unhealthy'
                            }}"
                        >
                          {{if
                            (eq server.lastHealthStatus "healthy")
                            (i18n "discourse_ai.mcp_servers.healthy")
                            (i18n "discourse_ai.mcp_servers.unhealthy")
                          }}
                        </span>
                      </div>
                    </div>
                    <DButton
                      @action={{fn this.openMcpToolSelector form data server}}
                      @label={{if
                        server.allToolsEnabled
                        "discourse_ai.ai_agent.mcp_server_choose_tools"
                        "discourse_ai.ai_agent.mcp_server_edit_tools"
                      }}
                      class="btn-default btn-small ai-agent-editor__mcp-server-action"
                    />
                  </div>
                {{/each}}
              </div>
            {{/if}}

            {{#let
              (this.totalSelectedToolTokens selectedTools selectedMcpServers)
              (this.totalSelectedToolCount selectedTools selectedMcpServers)
              as |totalSelectedToolTokens totalSelectedToolCount|
            }}
              {{#let
                (this.toolTokenSeverity
                  totalSelectedToolTokens totalSelectedToolCount
                )
                (this.toolTokenOnlySeverity totalSelectedToolTokens)
                (this.toolCountOnlySeverity totalSelectedToolCount)
                (this.tooManyTools totalSelectedToolCount)
                as |toolTokenSeverity toolTokenOnlySeverity toolCountOnlySeverity tooManyTools|
              }}
                {{#if (gt totalSelectedToolCount 0)}}
                  <div
                    class="ai-agent-editor__tool-context-cost
                      {{if
                        (eq toolTokenSeverity 'high')
                        '--high'
                        (if (eq toolTokenSeverity 'medium') '--medium' '--low')
                      }}"
                  >
                    <ul class="ai-agent-editor__tool-token-list">
                      {{#each selectedTools as |tool|}}
                        <li class="ai-agent-editor__tool-token-item">
                          <span>{{tool.name}}</span>
                          <span class="ai-agent-editor__tool-token-count">
                            {{tool.tokenCount}}
                            {{i18n "discourse_ai.ai_agent.tokens"}}
                          </span>
                        </li>
                      {{/each}}
                      {{#each selectedMcpServers as |server|}}
                        <li class="ai-agent-editor__tool-token-item">
                          <span>
                            {{i18n
                              "discourse_ai.ai_agent.mcp_server_cost_name"
                              name=server.name
                            }}
                          </span>
                          <span class="ai-agent-editor__tool-token-count">
                            {{i18n
                              "discourse_ai.ai_agent.mcp_server_cost_value"
                              tokens=server.selectedTokenCount
                              count=server.selectedToolCount
                            }}
                          </span>
                        </li>
                      {{/each}}
                    </ul>
                    <div class="ai-agent-editor__tool-context-cost-header">
                      <span class="ai-agent-editor__tool-context-cost-label">
                        {{i18n "discourse_ai.ai_agent.context_cost"}}
                      </span>
                    </div>
                    <div class="ai-agent-editor__tool-context-cost-bar">
                      <span
                        class="ai-agent-editor__tool-context-cost-bar-indicator --token"
                        style={{this.toolTokenIndicatorStyle
                          totalSelectedToolTokens
                        }}
                      >
                        {{icon "caret-down"}}
                      </span>
                      <span
                        class="ai-agent-editor__tool-context-cost-bar-indicator --count"
                        style={{this.toolCountIndicatorStyle
                          totalSelectedToolCount
                        }}
                      >
                        {{icon "caret-up"}}
                      </span>
                    </div>
                    <span class="ai-agent-editor__tool-context-cost-legend">
                      <span
                        class="ai-agent-editor__tool-context-cost-legend-item --token"
                      >
                        {{icon "caret-down"}}
                        {{i18n "discourse_ai.ai_agent.token_usage"}}:
                        <span
                          class="ai-agent-editor__tool-context-cost-value
                            {{toolTokenOnlySeverity}}"
                        >
                          {{i18n
                            "discourse_ai.ai_agent.tool_tokens_total"
                            tokens=totalSelectedToolTokens
                          }}
                        </span>
                      </span>
                      <span
                        class="ai-agent-editor__tool-context-cost-legend-item --count"
                      >
                        {{icon "caret-up"}}
                        {{i18n "discourse_ai.ai_agent.tool_count"}}:
                        <span
                          class="ai-agent-editor__tool-context-cost-value
                            {{toolCountOnlySeverity}}"
                        >
                          {{i18n
                            "discourse_ai.ai_agent.tool_count_value"
                            count=totalSelectedToolCount
                          }}
                        </span>
                      </span>
                    </span>
                    {{#if (eq toolTokenSeverity "medium")}}
                      <div class="ai-agent-editor__tool-context-cost-warning">
                        <span>
                          {{i18n "discourse_ai.ai_agent.tool_severity_medium"}}:
                        </span>
                        {{i18n "discourse_ai.ai_agent.tool_tokens_warning"}}
                      </div>
                    {{/if}}
                    {{#if (eq toolTokenSeverity "high")}}
                      <div class="ai-agent-editor__tool-context-cost-warning">
                        {{#if tooManyTools}}
                          <span>
                            {{i18n
                              "discourse_ai.ai_agent.tool_severity_too_many"
                            }}:
                          </span>
                          {{i18n "discourse_ai.ai_agent.tool_count_warning"}}
                        {{else}}
                          <span>
                            {{i18n "discourse_ai.ai_agent.tool_severity_high"}}:
                          </span>
                          {{i18n "discourse_ai.ai_agent.tool_tokens_warning"}}
                        {{/if}}
                      </div>
                    {{/if}}
                  </div>
                {{/if}}
              {{/let}}
            {{/let}}
          {{/let}}

          {{#if (gt data.tools.length 0)}}
            <form.Field
              @name="forcedTools"
              @title={{i18n "discourse_ai.ai_agent.forced_tools"}}
              @format="large"
              @type="custom"
              as |field|
            >
              <field.Control>
                <AiToolSelector
                  @value={{field.value}}
                  @disabled={{data.system}}
                  @onChange={{field.set}}
                  @content={{this.availableForcedTools data.tools}}
                />
              </field.Control>
            </form.Field>
          {{/if}}

          {{#if (gt data.forcedTools.length 0)}}
            <form.Field
              @name="forced_tool_count"
              @title={{i18n "discourse_ai.ai_agent.forced_tool_strategy"}}
              @format="large"
              @type="select"
              as |field|
            >
              <field.Control @includeNone={{false}} as |select|>
                {{#each this.forcedToolStrategies as |fts|}}
                  <select.Option @value={{fts.id}}>{{fts.name}}</select.Option>
                {{/each}}
              </field.Control>
            </form.Field>
          {{/if}}

          <form.Field
            @name="execution_mode"
            @title={{i18n "discourse_ai.ai_agent.execution_mode"}}
            @tooltip={{i18n "discourse_ai.ai_agent.execution_mode_help"}}
            @format="large"
            @onSet={{this.onExecutionModeChange}}
            @type="select"
            as |field|
          >
            <field.Control @includeNone={{false}} as |select|>
              {{#each this.executionModes as |mode|}}
                <select.Option @value={{mode.id}}>{{mode.name}}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>

          {{#if (eq data.execution_mode "agentic")}}
            <form.Field
              @name="max_turn_tokens"
              @title={{i18n "discourse_ai.ai_agent.max_turn_tokens"}}
              @tooltip={{i18n "discourse_ai.ai_agent.max_turn_tokens_help"}}
              @format="large"
              @type="input-number"
              as |field|
            >
              <field.Control @min={{1}} lang="en" />
            </form.Field>

            <form.Field
              @name="compression_threshold"
              @title={{i18n "discourse_ai.ai_agent.compression_threshold"}}
              @tooltip={{i18n
                "discourse_ai.ai_agent.compression_threshold_help"
              }}
              @format="large"
              @type="input-number"
              as |field|
            >
              <field.Control @min={{20}} @max={{99}} lang="en" />
            </form.Field>
          {{/if}}

          {{#unless (eq data.execution_mode "agentic")}}
            <form.Field
              @name="max_context_posts"
              @title={{i18n "discourse_ai.ai_agent.max_context_posts"}}
              @tooltip={{i18n "discourse_ai.ai_agent.max_context_posts_help"}}
              @format="large"
              @type="input-number"
              as |field|
            >
              <field.Control lang="en" />
            </form.Field>
          {{/unless}}

          {{#if (gt data.tools.length 0)}}
            <AiAgentToolOptions
              @form={{form}}
              @data={{data}}
              @llms={{@agents.resultSetMeta.llms}}
              @allTools={{@agents.resultSetMeta.tools}}
            />
          {{/if}}

          <form.Field
            @name="show_thinking"
            @title={{i18n "discourse_ai.ai_agent.show_thinking"}}
            @tooltip={{i18n "discourse_ai.ai_agent.show_thinking_help"}}
            @showTitle={{false}}
            @format="large"
            @type="checkbox"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Field
            @name="require_approval"
            @title={{i18n "discourse_ai.ai_agent.require_approval"}}
            @tooltip={{i18n "discourse_ai.ai_agent.require_approval_help"}}
            @format="large"
            @type="checkbox"
            as |field|
          >
            <field.Control />
          </form.Field>
        </form.Section>

        {{#if this.siteSettings.ai_embeddings_enabled}}
          <form.Section @title={{i18n "discourse_ai.rag.title"}}>
            <form.Field
              @name="rag_uploads"
              @title={{i18n "discourse_ai.rag.uploads.title"}}
              @format="full"
              @type="custom"
              as |field|
            >
              <field.Control>
                <RagUploader
                  @target={{data}}
                  @targetName="AiAgent"
                  @updateUploads={{fn this.updateUploads form}}
                  @onRemove={{fn this.removeUpload form data field.value}}
                  @allowImages={{@agents.resultSetMeta.settings.rag_images_enabled}}
                />
              </field.Control>
            </form.Field>

            <RagOptionsFk
              @form={{form}}
              @data={{data}}
              @llms={{@agents.resultSetMeta.llms}}
              @allowImages={{@agents.resultSetMeta.settings.rag_images_enabled}}
            >
              <form.Field
                @name="rag_conversation_chunks"
                @title={{i18n "discourse_ai.ai_agent.rag_conversation_chunks"}}
                @tooltip={{i18n
                  "discourse_ai.ai_agent.rag_conversation_chunks_help"
                }}
                @format="large"
                @type="input-number"
                as |field|
              >
                <field.Control step="any" lang="en" />
              </form.Field>
            </RagOptionsFk>
          </form.Section>
        {{/if}}

        <form.Section @title={{i18n "discourse_ai.ai_agent.ai_bot.title"}}>
          <form.Field
            @name="enabled"
            @title={{i18n "discourse_ai.ai_agent.enabled"}}
            @onSet={{fn this.toggleEnabled data}}
            @type="toggle"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Field
            @name="priority"
            @title={{i18n "discourse_ai.ai_agent.priority"}}
            @onSet={{fn this.togglePriority data}}
            @tooltip={{i18n "discourse_ai.ai_agent.priority_help"}}
            @type="toggle"
            as |field|
          >
            <field.Control />
          </form.Field>

          {{#if @model.isNew}}
            <div>{{i18n "discourse_ai.ai_agent.ai_bot.save_first"}}</div>
          {{else}}
            {{#if data.default_llm_id}}
              <form.Field
                @name="force_default_llm"
                @title={{i18n "discourse_ai.ai_agent.force_default_llm"}}
                @showTitle={{false}}
                @format="large"
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>
            {{/if}}

            <form.Container
              @title={{i18n "discourse_ai.ai_agent.user"}}
              @tooltip={{unless
                data.user
                (i18n "discourse_ai.ai_agent.create_user_help")
              }}
              class="ai-agent-editor__ai_bot_user"
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
                  @label="discourse_ai.ai_agent.create_user"
                  class="btn-default ai-agent-editor__create-user"
                />
              {{/if}}
            </form.Container>

            {{#if data.user}}
              <form.Field
                @name="allow_personal_messages"
                @title={{i18n "discourse_ai.ai_agent.allow_personal_messages"}}
                @tooltip={{i18n
                  "discourse_ai.ai_agent.allow_personal_messages_help"
                }}
                @showTitle={{false}}
                @format="large"
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>

              <form.Field
                @name="allow_topic_mentions"
                @title={{i18n "discourse_ai.ai_agent.allow_topic_mentions"}}
                @tooltip={{i18n
                  "discourse_ai.ai_agent.allow_topic_mentions_help"
                }}
                @showTitle={{false}}
                @format="large"
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>

              {{#if this.chatPluginEnabled}}
                <form.Field
                  @name="allow_chat_direct_messages"
                  @title={{i18n
                    "discourse_ai.ai_agent.allow_chat_direct_messages"
                  }}
                  @tooltip={{i18n
                    "discourse_ai.ai_agent.allow_chat_direct_messages_help"
                  }}
                  @showTitle={{false}}
                  @format="large"
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <form.Field
                  @name="allow_chat_channel_mentions"
                  @title={{i18n
                    "discourse_ai.ai_agent.allow_chat_channel_mentions"
                  }}
                  @tooltip={{i18n
                    "discourse_ai.ai_agent.allow_chat_channel_mentions_help"
                  }}
                  @showTitle={{false}}
                  @format="large"
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </form.Field>
              {{/if}}
            {{/if}}
          {{/if}}
        </form.Section>

        <form.Actions>
          <form.Submit />

          {{#unless (or @model.isNew @model.system)}}
            <form.Button
              @label="discourse_ai.ai_agent.export"
              @action={{this.exportAgent}}
              class="btn-default ai-agent-editor__export"
            />
            <form.Button
              @action={{this.delete}}
              @label="discourse_ai.ai_agent.delete"
              @icon="trash-can"
              class="btn-danger"
            />
          {{/unless}}
        </form.Actions>
      </Form>
    </div>
  </template>
}
