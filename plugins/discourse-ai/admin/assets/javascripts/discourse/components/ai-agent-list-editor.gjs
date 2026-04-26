import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AiAgent from "../admin/models/ai-agent";
import AiAgentEditor from "./ai-agent-editor";

const LAYOUT_BUTTONS = [
  {
    id: "table",
    label: "discourse_ai.layout.table",
    icon: "discourse-table",
  },
  {
    id: "card",
    label: "discourse_ai.layout.card",
    icon: "table",
  },
];

export default class AiAgentListEditor extends Component {
  @service adminPluginNavManager;
  @service keyValueStore;
  @service capabilities;
  @service dialog;

  @tracked currentLayout = LAYOUT_BUTTONS[0];

  constructor() {
    super(...arguments);
    const savedLayoutId = this.keyValueStore.get("ai-agent-list-layout");
    if (savedLayoutId) {
      const found = LAYOUT_BUTTONS.find((b) => b.id === savedLayoutId);
      if (found) {
        this.currentLayout = found;
      }
    }
  }

  get searchableProps() {
    return ["name", "description"];
  }

  get dropdownOptions() {
    let features = [];
    (this.args.agents?.content || []).forEach((agent) => {
      (agent.features || []).forEach((feature) => {
        if (feature?.module_name && !features.includes(feature.module_name)) {
          features.push(feature.module_name);
        }
      });
    });
    features.sort();
    return [
      {
        value: "all",
        label: i18n("discourse_ai.ai_agent.filters.all_features"),
        filterFn: () => true,
      },
      ...features.map((name) => ({
        value: name,
        label: i18n(`discourse_ai.features.${name}.name`),
        filterFn: (agent) =>
          (agent.features || []).some(
            (feature) => feature.module_name === name
          ),
      })),
    ];
  }

  @action
  async toggleEnabled(agent) {
    const oldValue = agent.enabled;
    const newValue = !oldValue;

    try {
      agent.set("enabled", newValue);
      await agent.save();
    } catch (err) {
      agent.set("enabled", oldValue);
      popupAjaxError(err);
    }
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onLayoutSelect(layoutId) {
    const found = LAYOUT_BUTTONS.find((b) => b.id === layoutId);
    if (found) {
      this.currentLayout = found;
      this.keyValueStore.set({
        key: "ai-agent-list-layout",
        value: layoutId,
      });
    }
    this.dMenu.close();
  }

  @action
  importAgent() {
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
        this.uploadAgent(json);
      } catch {
        this.dialog.alert(i18n("discourse_ai.ai_agent.import_error_not_json"));
      }
    };
    reader.readAsText(file);
  }

  uploadAgent(agentData, force = false) {
    let url = `/admin/plugins/discourse-ai/ai-agents/import.json`;
    const payload = agentData;
    if (force) {
      payload.force = true;
    }

    return ajax(url, {
      type: "POST",
      data: JSON.stringify(payload),
      contentType: "application/json",
    })
      .then((result) => {
        const agentPayload = result.ai_agent || result;
        let agent = AiAgent.create(agentPayload);
        let existingAgent = this.args.agents.content.find(
          (item) => item.id === agent.id
        );
        if (existingAgent) {
          removeValueFromArray(this.args.agents.content, existingAgent);
        }
        this.args.agents.content.unshift(agent);
      })
      .catch((error) => {
        if (error.jqXHR?.status === 422) {
          this.dialog.confirm({
            message:
              i18n("discourse_ai.ai_agent.import_error_conflict", {
                name: agentData.agent?.name ?? agentData.persona?.name,
              }) +
              "\n" +
              error.jqXHR.responseJSON?.errors?.join("\n"),
            confirmButtonLabel: "discourse_ai.ai_agent.overwrite",
            didConfirm: () => this.uploadAgent(agentData, true),
          });
        } else {
          popupAjaxError(error);
        }
      });
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-agents"
      @label={{i18n "discourse_ai.ai_agent.short_title"}}
    />
    <section class="ai-agent-list-editor__current admin-detail">
      {{#if @currentAgent}}
        <AiAgentEditor @model={{@currentAgent}} @agents={{@agents}} />
      {{else}}
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.ai_agent.short_title"}}
          @descriptionLabel={{i18n "discourse_ai.ai_agent.agent_description"}}
          @learnMoreUrl="https://meta.discourse.org/t/ai-bot-agents/306099"
        >
          <:actions as |actions|>
            <actions.Default
              @label="discourse_ai.ai_agent.import"
              @action={{this.importAgent}}
              @icon="upload"
              class="ai-agent-list-editor__import-button"
            />
            <actions.Primary
              @label="discourse_ai.ai_agent.new"
              @route="adminPlugins.show.discourse-ai-agents.new"
              @icon="plus"
              class="ai-agent-list-editor__new-button"
            />
          </:actions>
        </DPageSubheader>
        {{#if @agents.content}}
          <AdminFilterControls
            @array={{@agents.content}}
            @searchableProps={{this.searchableProps}}
            @dropdownOptions={{this.dropdownOptions}}
            @inputPlaceholder={{i18n "discourse_ai.ai_agent.filters.text"}}
            @noResultsMessage={{i18n
              "discourse_ai.ai_agent.filters.no_results"
            }}
          >
            <:actions>
              {{#if this.capabilities.viewport.md}}
                <DMenu
                  @modalForMobile={{true}}
                  @autofocus={{true}}
                  @identifier="agent-list-layout"
                  @onRegisterApi={{this.onRegisterApi}}
                  @triggerClass="btn-default btn-icon"
                >
                  <:trigger>
                    {{icon this.currentLayout.icon}}
                  </:trigger>
                  <:content>
                    <DropdownMenu as |dropdown|>
                      {{#each LAYOUT_BUTTONS as |button|}}
                        <dropdown.item>
                          <DButton
                            @label={{button.label}}
                            @icon={{button.icon}}
                            class="btn-transparent"
                            @action={{fn this.onLayoutSelect button.id}}
                          />
                        </dropdown.item>
                      {{/each}}
                    </DropdownMenu>
                  </:content>
                </DMenu>
              {{/if}}
            </:actions>
            <:content as |filteredAgents|>
              <table
                class={{concatClass
                  "content-list ai-agent-list-editor d-table"
                  (concat "--layout-" this.currentLayout.id)
                }}
              >
                <thead class="d-table__header">
                  <tr>
                    <th>{{i18n "discourse_ai.ai_agent.name"}}</th>
                    <th>{{i18n "discourse_ai.llms.short_title"}}</th>
                    <th>{{i18n "discourse_ai.features.short_title"}}</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each filteredAgents as |agent|}}
                    <tr
                      data-agent-id={{agent.id}}
                      class={{concatClass
                        "ai-agent-list__row d-table__row"
                        (if agent.priority "--priority")
                        (if agent.enabled "--enabled")
                      }}
                    >
                      <td class="d-table__cell --overview">
                        <div class="ai-agent-list__name-with-description">
                          <h3 class="ai-agent-list__name">
                            {{#if agent.user}}
                              {{avatar agent.user imageSize="tiny"}}
                            {{/if}}
                            {{agent.name}}
                          </h3>
                          <div class="ai-agent-list__description">
                            {{agent.description}}
                          </div>
                        </div>
                      </td>
                      <td class="ai-agent-list__llms">
                        {{#if agent.default_llm}}
                          <span class="--card-label">
                            {{i18n "discourse_ai.ai_agent.llms_list"}}
                          </span>
                          <DButton
                            class="btn-flat btn-small ai-agent-list__row-item-feature"
                            @translatedLabel={{agent.default_llm.display_name}}
                            @route="adminPlugins.show.discourse-ai-llms.edit"
                            @routeModels={{agent.default_llm.id}}
                          />
                        {{/if}}
                      </td>
                      <td class="ai-agent-list__features">
                        {{#if agent.features.length}}
                          <span class="--card-label">
                            {{i18n
                              "discourse_ai.ai_agent.features_list"
                              count=agent.features.length
                            }}
                          </span>
                          {{#each agent.features as |feature index|}}
                            <span class="ai-agent-list__feature-list">
                              {{#if (gt index 0)}}, {{/if}}
                              <DButton
                                class="btn-flat btn-small ai-agent-list__row-item-feature"
                                @translatedLabel={{i18n
                                  (concat
                                    "discourse_ai.features."
                                    feature.module_name
                                    ".name"
                                  )
                                }}
                                @route="adminPlugins.show.discourse-ai-features.edit"
                                @routeModels={{feature.id}}
                              />
                            </span>
                          {{/each}}
                        {{/if}}
                      </td>
                      <td class="d-table__cell --controls">
                        <LinkTo
                          @route="adminPlugins.show.discourse-ai-agents.edit"
                          @model={{agent}}
                          class="btn btn-default btn-text btn-small"
                        >{{i18n "discourse_ai.ai_agent.edit"}} </LinkTo>
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </:content>
          </AdminFilterControls>
        {{else}}
          <AdminConfigAreaEmptyList
            @ctaLabel="discourse_ai.ai_agent.new"
            @ctaRoute="adminPlugins.show.discourse-ai-agents.new"
            @ctaClass="ai-agent-list-editor__empty-new-button"
            @emptyLabel="discourse_ai.ai_agent.no_agents"
          />
        {{/if}}
      {{/if}}
    </section>
  </template>
}
