import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { eq } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiTool from "../admin/models/ai-tool";
import AiMcpServerToolsModal from "./modal/ai-mcp-server-tools-modal";

export default class AiToolListEditor extends Component {
  @service adminPluginNavManager;
  @service router;
  @service dialog;
  @service modal;

  @tracked expandedCategory = null;

  get sortedTools() {
    return [...(this.args.tools.content || [])].sort((a, b) =>
      (a.name || "").localeCompare(b.name || "")
    );
  }

  get sortedMcpServers() {
    return [...(this.args.mcpServers?.content || [])].sort((a, b) =>
      (a.name || "").localeCompare(b.name || "")
    );
  }

  get hasScriptTools() {
    return this.sortedTools.length > 0;
  }

  get hasMcpServers() {
    return this.sortedMcpServers.length > 0;
  }

  get hasAnyItems() {
    return this.hasScriptTools || this.hasMcpServers;
  }

  get dropdownPresets() {
    return this.args.tools.resultSetMeta.presets.filter((preset) => {
      // Filter out individual image generation presets, keep only the category
      return !preset.category || preset.is_category;
    });
  }

  get categoryPresets() {
    if (!this.expandedCategory) {
      return [];
    }

    const presets = this.args.tools.resultSetMeta.presets.filter(
      (preset) =>
        preset.category === this.expandedCategory && !preset.is_category
    );

    // Separate "Custom" from others
    const customPreset = presets.find(
      (p) => p.preset_id === "image_generation_custom"
    );
    const otherPresets = presets
      .filter((p) => p.preset_id !== "image_generation_custom")
      .sort((a, b) => a.provider.localeCompare(b.provider));

    return { otherPresets, customPreset };
  }

  get lastIndexOfPresets() {
    return this.dropdownPresets.length - 1;
  }

  @action
  expandCategory(preset) {
    this.expandedCategory = preset.category;
  }

  @action
  collapseCategory() {
    this.expandedCategory = null;
  }

  @action
  resetMenuState() {
    this.expandedCategory = null;
  }

  @action
  routeToNewTool(preset) {
    const queryParams = { presetId: preset.preset_id };

    return this.router.transitionTo(
      "adminPlugins.show.discourse-ai-tools.new",
      {
        queryParams,
      }
    );
  }

  @action
  routeToNewMcpServer() {
    return this.router.transitionTo(
      "adminPlugins.show.discourse-ai-tools.mcp-server-new"
    );
  }

  @action
  showMcpServerTools(server) {
    this.modal.show(AiMcpServerToolsModal, {
      model: {
        serverName: server.name,
        tools: server.tools || [],
      },
    });
  }

  credentialStatus(tool) {
    const contracts = tool.secret_contracts || [];
    if (contracts.length === 0) {
      return [];
    }

    const bindings = tool.secret_bindings || [];
    const boundAliases = new Set(
      bindings.filter((b) => b.alias && b.ai_secret_id).map((b) => b.alias)
    );

    return contracts.map((contract) => ({
      alias: contract.alias,
      bound: boundAliases.has(contract.alias),
    }));
  }

  @action
  importTool() {
    // Create a hidden file input and click it
    const fileInput = document.createElement("input");
    fileInput.type = "file";
    fileInput.accept = ".json";
    fileInput.style.display = "none";
    fileInput.onchange = (event) => this.handleFileSelect(event);
    document.body.appendChild(fileInput);
    fileInput.click();
    document.body.removeChild(fileInput);
  }

  @action
  handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file) {
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const json = JSON.parse(e.target.result);
        this.uploadTool(json.ai_tool);
      } catch {
        this.dialog.alert(i18n("discourse_ai.tools.import_error_not_json"));
      }
    };
    reader.readAsText(file);
  }

  uploadTool(toolData, force = false) {
    let url = `/admin/plugins/discourse-ai/ai-tools/import.json`;
    const payload = {
      ai_tool: toolData,
    };
    if (force) {
      payload.force = true;
    }

    return ajax(url, {
      type: "POST",
      data: JSON.stringify(payload),
      contentType: "application/json",
    })
      .then((result) => {
        let tool = AiTool.create(result.ai_tool);
        let existingTool = this.args.tools.content.find(
          (item) => item.id === tool.id
        );
        if (existingTool) {
          removeValueFromArray(this.args.tools.content, existingTool);
        }
        this.args.tools.content.unshift(tool);
      })
      .catch((error) => {
        if (error.jqXHR?.status === 409) {
          this.dialog.confirm({
            message: i18n("discourse_ai.tools.import_error_conflict", {
              name: toolData.tool_name,
            }),
            confirmButtonLabel: "discourse_ai.tools.overwrite",
            didConfirm: () => this.uploadTool(toolData, true),
          });
        } else {
          popupAjaxError(error);
        }
      });
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.tools.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-tools"
    />
    <section class="ai-tool-list-editor__current admin-detail pull-left">
      <DPageSubheader
        @descriptionLabel={{i18n "discourse_ai.tools.subheader_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/ai-bot-custom-tools/314103"
        @titleLabel={{i18n "discourse_ai.tools.short_title"}}
      >
        <:actions as |actions|>
          <actions.Default
            class="ai-tool-list-editor__import-button"
            @action={{this.importTool}}
            @icon="upload"
            @label="discourse_ai.tools.import"
          />
          <actions.Default
            class="ai-tool-list-editor__new-mcp-button"
            @action={{this.routeToNewMcpServer}}
            @icon="plus"
            @label="discourse_ai.mcp_servers.new"
          />
          <actions.Wrapped>
            <DMenu
              @icon="plus"
              @label={{i18n "discourse_ai.tools.new"}}
              @onClose={{this.resetMenuState}}
              @placement="bottom-end"
              @triggerClass="btn-default btn-small ai-tool-list-editor__new-button"
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  {{#if this.expandedCategory}}
                    <dropdown.item>
                      <DButton
                        class="btn-transparent"
                        @action={{this.collapseCategory}}
                        @icon="chevron-left"
                        @label="back_button"
                      />
                    </dropdown.item>
                    <dropdown.divider />
                    {{#each this.categoryPresets.otherPresets as |preset|}}
                      <dropdown.item>
                        <div
                          class="ai-tool-preset-item"
                          data-option={{preset.preset_id}}
                          role="button"
                          {{on "click" (fn this.routeToNewTool preset)}}
                        >
                          <span
                            class="ai-tool-preset-provider"
                          >{{preset.provider}}</span>
                          <span
                            class="ai-tool-preset-model"
                          >{{preset.model_name}}</span>
                        </div>
                      </dropdown.item>
                    {{/each}}

                    {{#if this.categoryPresets.customPreset}}
                      <dropdown.divider />
                      <dropdown.item>
                        <DButton
                          class="btn-transparent"
                          data-option={{this.categoryPresets.customPreset.preset_id}}
                          @action={{fn
                            this.routeToNewTool
                            this.categoryPresets.customPreset
                          }}
                          @translatedLabel={{this.categoryPresets.customPreset.preset_name}}
                        />
                      </dropdown.item>
                    {{/if}}
                  {{else}}
                    {{#each this.dropdownPresets as |preset index|}}
                      {{#if (eq index this.lastIndexOfPresets)}}
                        <dropdown.divider />
                      {{/if}}

                      <dropdown.item>
                        <DButton
                          class="btn-transparent"
                          data-option={{preset.preset_id}}
                          @action={{if
                            preset.is_category
                            (fn this.expandCategory preset)
                            (fn this.routeToNewTool preset)
                          }}
                          @translatedLabel={{preset.preset_name}}
                        />
                      </dropdown.item>
                    {{/each}}
                  {{/if}}
                </DDropdownMenu>

              </:content>
            </DMenu>
          </actions.Wrapped>
        </:actions>
      </DPageSubheader>

      {{#if this.hasAnyItems}}
        {{#if this.hasScriptTools}}
          <h3 class="ai-tool-list-editor__section-title">
            {{i18n "discourse_ai.tools.script_tools"}}
          </h3>
          <table class="d-table ai-tool-list-editor">
            <thead class="d-table__header">
              <th>{{i18n "discourse_ai.tools.name"}}</th>
              <th></th>
            </thead>
            <tbody>
              {{#each this.sortedTools as |tool|}}
                <tr
                  class="ai-tool-list__row d-table__row"
                  data-tool-id={{tool.id}}
                >
                  <td class="d-table__cell --overview">
                    <div class="ai-tool-list__name-with-description">
                      <div class="ai-tool-list__name">
                        <strong>
                          {{tool.name}}
                        </strong>
                      </div>
                      <div class="ai-tool-list__description">
                        {{tool.description}}
                      </div>
                      {{#if tool.secret_contracts.length}}
                        <div class="ai-tool-list__credentials">
                          {{#each (this.credentialStatus tool) as |cred|}}
                            <span
                              class="ai-tool-list__credential-badge
                                {{if
                                  cred.bound
                                  'ai-tool-list__credential-badge--bound'
                                  'ai-tool-list__credential-badge--missing'
                                }}"
                            >
                              {{#if cred.bound}}
                                {{dIcon "check"}}
                              {{else}}
                                {{dIcon "triangle-exclamation"}}
                              {{/if}}
                              {{cred.alias}}
                              {{#unless cred.bound}}
                                <span class="ai-tool-list__credential-not-set">
                                  {{i18n
                                    "discourse_ai.tools.credential_not_set"
                                  }}
                                </span>
                              {{/unless}}
                            </span>
                          {{/each}}
                        </div>
                      {{/if}}
                    </div>
                  </td>
                  <td class="d-table__cell --controls">
                    <LinkTo
                      class="btn btn-default btn-text btn-small"
                      @model={{tool}}
                      @route="adminPlugins.show.discourse-ai-tools.edit"
                    >{{i18n "discourse_ai.tools.edit"}}</LinkTo>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}

        {{#if this.hasMcpServers}}
          <h3 class="ai-tool-list-editor__section-title">
            {{i18n "discourse_ai.mcp_servers.short_title"}}
          </h3>
          <table class="d-table ai-tool-list-editor">
            <thead class="d-table__header">
              <th>{{i18n "discourse_ai.mcp_servers.name"}}</th>
              <th>{{i18n "discourse_ai.mcp_servers.health"}}</th>
              <th></th>
            </thead>
            <tbody>
              {{#each this.sortedMcpServers as |server|}}
                <tr
                  class="ai-tool-list__row d-table__row"
                  data-mcp-server-id={{server.id}}
                >
                  <td class="d-table__cell --overview">
                    <div class="ai-tool-list__name-with-description">
                      <div class="ai-tool-list__name">
                        <strong>{{server.name}}</strong>
                      </div>
                      <div class="ai-tool-list__description">
                        {{server.description}}
                      </div>
                      <div class="ai-tool-list__mcp-meta">
                        {{#if server.tools.length}}
                          <button
                            class="ai-tool-list__mcp-tools-button"
                            type="button"
                            {{on "click" (fn this.showMcpServerTools server)}}
                          >
                            {{i18n
                              "discourse_ai.mcp_servers.tool_count"
                              count=server.tool_count
                            }}
                          </button>
                        {{else}}
                          {{i18n
                            "discourse_ai.mcp_servers.tool_count"
                            count=server.tool_count
                          }}
                        {{/if}}
                      </div>
                    </div>
                  </td>
                  <td class="d-table__cell --detail">
                    <span
                      class="ai-tool-list__credential-badge
                        {{if
                          (eq server.last_health_status 'healthy')
                          'ai-tool-list__credential-badge--bound'
                          'ai-tool-list__credential-badge--missing'
                        }}"
                    >
                      {{if
                        (eq server.last_health_status "healthy")
                        (i18n "discourse_ai.mcp_servers.healthy")
                        (i18n "discourse_ai.mcp_servers.unhealthy")
                      }}
                    </span>
                  </td>
                  <td class="d-table__cell --controls">
                    <LinkTo
                      class="btn btn-default btn-text btn-small"
                      @model={{server}}
                      @route="adminPlugins.show.discourse-ai-tools.mcp-server-edit"
                    >{{i18n "discourse_ai.mcp_servers.edit"}}</LinkTo>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}
      {{else}}
        <AdminConfigAreaEmptyList @emptyLabel="discourse_ai.tools.no_tools">
          <div class="ai-tool-list-editor__empty-list-buttons">
            <DMenu
              @icon="plus"
              @label={{i18n "discourse_ai.tools.new"}}
              @onClose={{this.resetMenuState}}
              @placement="bottom-end"
              @triggerClass="btn-default btn-small ai-tool-list-editor__empty-new-button"
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  {{#if this.expandedCategory}}
                    <dropdown.item>
                      <DButton
                        class="btn-transparent"
                        @action={{this.collapseCategory}}
                        @icon="chevron-left"
                        @label="back_button"
                      />
                    </dropdown.item>
                    <dropdown.divider />
                    {{#each this.categoryPresets.otherPresets as |preset|}}
                      <dropdown.item>
                        <div
                          class="ai-tool-preset-item"
                          data-option={{preset.preset_id}}
                          role="button"
                          {{on "click" (fn this.routeToNewTool preset)}}
                        >
                          <span
                            class="ai-tool-preset-provider"
                          >{{preset.provider}}</span>
                          <span
                            class="ai-tool-preset-model"
                          >{{preset.model_name}}</span>
                        </div>
                      </dropdown.item>
                    {{/each}}

                    {{#if this.categoryPresets.customPreset}}
                      <dropdown.divider />
                      <dropdown.item>
                        <DButton
                          class="btn-transparent"
                          data-option={{this.categoryPresets.customPreset.preset_id}}
                          @action={{fn
                            this.routeToNewTool
                            this.categoryPresets.customPreset
                          }}
                          @translatedLabel={{this.categoryPresets.customPreset.preset_name}}
                        />
                      </dropdown.item>
                    {{/if}}
                  {{else}}
                    {{#each this.dropdownPresets as |preset index|}}
                      {{#if (eq index this.lastIndexOfPresets)}}
                        <dropdown.divider />
                      {{/if}}

                      <dropdown.item>
                        <DButton
                          class="btn-transparent"
                          data-option={{preset.preset_id}}
                          @action={{if
                            preset.is_category
                            (fn this.expandCategory preset)
                            (fn this.routeToNewTool preset)
                          }}
                          @translatedLabel={{preset.preset_name}}
                        />
                      </dropdown.item>
                    {{/each}}
                  {{/if}}
                </DDropdownMenu>

              </:content>
            </DMenu>
            <DButton
              class="btn-default btn-small ai-tool-list-editor__empty-new-mcp-button"
              @action={{this.routeToNewMcpServer}}
              @icon="plus"
              @label="discourse_ai.mcp_servers.new"
            />
          </div></AdminConfigAreaEmptyList>
      {{/if}}
    </section>
  </template>
}
