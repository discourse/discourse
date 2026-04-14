import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class AiAgentMcpToolSelectorModal extends Component {
  @tracked filter = "";
  @tracked selectedToolNames = null;

  @cached
  get tools() {
    return [...(this.args.model?.tools || [])].sort((firstTool, secondTool) =>
      (firstTool.title || firstTool.name || "").localeCompare(
        secondTool.title || secondTool.name || ""
      )
    );
  }

  get allToolNames() {
    return this.tools.map((tool) => tool.name);
  }

  get defaultSelectedToolNames() {
    const initialSelection = this.args.model?.selectedToolNames;

    if (initialSelection?.length) {
      const availableToolNames = new Set(this.allToolNames);
      return initialSelection.filter((name) => availableToolNames.has(name));
    }

    return this.allToolNames;
  }

  get effectiveSelectedToolNames() {
    return this.selectedToolNames ?? this.defaultSelectedToolNames;
  }

  @cached
  get effectiveSelectedToolNameSet() {
    return new Set(this.effectiveSelectedToolNames);
  }

  get filteredTools() {
    const filter = this.filter.trim().toLowerCase();
    if (!filter) {
      return this.tools;
    }

    return this.tools.filter((tool) => {
      return [tool.title, tool.name, tool.description]
        .filter(Boolean)
        .some((value) => value.toLowerCase().includes(filter));
    });
  }

  get selectedCount() {
    return this.tools.filter((tool) =>
      this.effectiveSelectedToolNameSet.has(tool.name)
    ).length;
  }

  @action
  isSelected(toolName) {
    return this.effectiveSelectedToolNameSet.has(toolName);
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value;
  }

  @action
  toggleTool(toolName, event) {
    if (event.target.checked) {
      this.selectedToolNames = [
        ...new Set([...this.effectiveSelectedToolNames, toolName]),
      ];
    } else {
      this.selectedToolNames = this.effectiveSelectedToolNames.filter(
        (selectedToolName) => selectedToolName !== toolName
      );
    }
  }

  @action
  selectAllVisible() {
    const selectedToolNames = new Set(this.effectiveSelectedToolNames);
    this.filteredTools.forEach((tool) => selectedToolNames.add(tool.name));
    this.selectedToolNames = this.tools
      .map((tool) => tool.name)
      .filter((toolName) => selectedToolNames.has(toolName));
  }

  @action
  clearAll() {
    this.selectedToolNames = [];
  }

  @action
  save() {
    const selectedToolNameSet = this.effectiveSelectedToolNameSet;
    const selectedToolNames = this.tools
      .map((tool) => tool.name)
      .filter((toolName) => selectedToolNameSet.has(toolName));

    if (selectedToolNames.length === 0) {
      this.args.model.onSave?.([]);
    } else if (selectedToolNames.length === this.tools.length) {
      this.args.model.onSave?.(null);
    } else {
      this.args.model.onSave?.(selectedToolNames);
    }

    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n
        "discourse_ai.ai_agent.mcp_tools_modal.title"
        name=@model.serverName
      }}
      @closeModal={{@closeModal}}
      @bodyClass="ai-agent-mcp-tools-modal__body"
      class="ai-agent-mcp-tools-modal"
    >
      <:body>
        <p class="ai-agent-mcp-tools-modal__summary">
          {{i18n "discourse_ai.ai_agent.mcp_tools_modal.summary"}}
        </p>

        <div class="ai-agent-mcp-tools-modal__controls">
          <input
            class="ai-agent-mcp-tools-modal__filter"
            type="search"
            value={{this.filter}}
            placeholder={{i18n
              "discourse_ai.ai_agent.mcp_tools_modal.filter_placeholder"
            }}
            {{on "input" this.updateFilter}}
          />

          <DButton
            @action={{this.selectAllVisible}}
            @label="discourse_ai.ai_agent.mcp_tools_modal.select_all"
            class="btn-default btn-small ai-agent-mcp-tools-modal__select-all"
          />

          <DButton
            @action={{this.clearAll}}
            @label="discourse_ai.ai_agent.mcp_tools_modal.clear_all"
            class="btn-default btn-small ai-agent-mcp-tools-modal__clear-all"
          />
        </div>

        <p class="ai-agent-mcp-tools-modal__selection-summary">
          {{i18n
            "discourse_ai.ai_agent.mcp_tools_modal.selection_summary"
            count=this.selectedCount
            total=this.tools.length
          }}
        </p>

        {{#if this.filteredTools.length}}
          {{#each this.filteredTools as |tool|}}
            <section
              class="ai-agent-mcp-tools-modal__tool"
              data-tool-name={{tool.name}}
            >
              <label class="ai-agent-mcp-tools-modal__tool-header">
                <span class="ai-agent-mcp-tools-modal__tool-checkbox">
                  <input
                    type="checkbox"
                    checked={{this.isSelected tool.name}}
                    {{on "change" (fn this.toggleTool tool.name)}}
                  />
                </span>
                <span class="ai-agent-mcp-tools-modal__tool-header-content">
                  <span class="ai-agent-mcp-tools-modal__tool-title">
                    {{if tool.title tool.title tool.name}}
                  </span>
                  <code class="ai-agent-mcp-tools-modal__tool-name">
                    {{tool.name}}
                  </code>
                </span>
                <span class="ai-agent-mcp-tools-modal__tool-token-count">
                  {{i18n
                    "discourse_ai.ai_agent.mcp_server_tokens_only"
                    tokens=tool.token_count
                  }}
                </span>
              </label>
            </section>
          {{/each}}
        {{else}}
          <p class="ai-agent-mcp-tools-modal__empty">
            {{i18n "discourse_ai.ai_agent.mcp_tools_modal.empty"}}
          </p>
        {{/if}}
      </:body>

      <:footer>
        <DButton @action={{this.save}} @label="save" class="btn-primary" />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
