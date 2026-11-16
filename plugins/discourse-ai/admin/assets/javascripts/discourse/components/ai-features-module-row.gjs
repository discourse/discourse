import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";
import { i18n } from "discourse-i18n";
import { enabledSettingControl } from "../lib/ai-feature-enabled-setting.js";
import { dedicatedSettingsRoute } from "../lib/ai-feature-settings-route.js";
import { setupLink } from "../lib/ai-feature-setup-links.js";
import AiFeatureSettingToggle from "./ai-feature-setting-toggle.gjs";
import AiFeaturesChatbotAgents from "./ai-features-chatbot-agents.gjs";
import AiFeaturesFeatureRow from "./ai-features-feature-row.gjs";
import AiFeaturesStatus from "./ai-features-status.gjs";

const AUTOMATION_MODULES = ["automation_reports", "automation_triage"];
const MODULES_WITHOUT_GROUPS = ["spam", "sentiment"];

/**
 * A collapsible AI module row and its features.
 *
 * Module state is passed as separate args because refreshed modules are
 * updated in place by the store, which getters reading `@module` would miss.
 */
export default class AiFeaturesModuleRow extends Component {
  @service router;

  featuresId = `ai-features-${dUniqueId()}`;

  @tracked _expanded = null;

  get isExpanded() {
    return this.args.forceExpanded || (this._expanded ?? false);
  }

  get isAutomation() {
    return AUTOMATION_MODULES.includes(this.args.module.module_name);
  }

  get showGroups() {
    return !MODULES_WITHOUT_GROUPS.includes(this.args.module.module_name);
  }

  get name() {
    return i18n(`discourse_ai.features.${this.args.module.module_name}.name`);
  }

  get description() {
    return i18n(
      `discourse_ai.features.${this.args.module.module_name}.description`
    );
  }

  get toggleLabel() {
    return i18n("discourse_ai.features.toggle", { name: this.name });
  }

  /**
   * Something that needs setup is not running, so it offers "Set up" rather than
   * a switch that would suggest otherwise.
   */
  get showToggle() {
    return this.control === "toggle" && this.status !== "setup";
  }

  get control() {
    return enabledSettingControl(this.enabledSetting);
  }

  get status() {
    if (this.args.status) {
      return this.args.status.state;
    }
    if (
      this.control === "setup" ||
      (this.#soleFeatureSetting && this.args.features[0].needs_setup)
    ) {
      return "setup";
    }
    return this.args.enabled ? "on" : "off";
  }

  get statusLabel() {
    if (this.args.status?.label_key) {
      return i18n(
        `discourse_ai.features.status.${this.args.status.label_key}`,
        {
          count: this.args.status.count,
        }
      );
    }

    if (this.status === "setup") {
      return i18n("discourse_ai.features.status.needs_setup");
    }

    if (this.status === "off") {
      return i18n("discourse_ai.features.status.off");
    }

    const features = this.args.features;
    return i18n("discourse_ai.features.status.on_with_features", {
      count: features.length,
      enabled: features.filter((feature) => feature.enabled).length,
    });
  }

  get modelSummary() {
    if (this.args.modelNames) {
      return this.args.modelNames.join(", ");
    }

    const names = this.args.features.flatMap((feature) =>
      (feature.llm_models || []).map((llm) => llm.name)
    );
    return [...new Set(names)].join(", ");
  }

  get statusSetupLink() {
    return setupLink(this.args.status?.note_key);
  }

  get statusNote() {
    const noteKey = this.args.status?.note_key;
    if (!noteKey) {
      return null;
    }

    const items = (this.args.status.missing || [])
      .map((item) => i18n(`discourse_ai.features.setup_items.${item}`))
      .join(", ");
    return i18n(`discourse_ai.features.status_notes.${noteKey}`, { items });
  }

  get settingsRoute() {
    return (
      dedicatedSettingsRoute(this.args.module.module_name) ??
      "adminPlugins.show.discourse-ai-features.edit"
    );
  }

  get settingsRouteModels() {
    return dedicatedSettingsRoute(this.args.module.module_name)
      ? undefined
      : this.args.module.id;
  }

  /**
   * A module without its own setting is switched by its only feature's setting,
   * so the switch sits on the module row instead of a single-row features table.
   */
  get enabledSetting() {
    return this.args.enabledSetting ?? this.#soleFeatureSetting;
  }

  get showFeatureEnabledColumn() {
    if (this.#soleFeatureSetting) {
      return false;
    }
    return this.args.features.some(
      (feature) =>
        feature.enabled_setting || (this.args.enabled && !feature.enabled)
    );
  }

  get accessByAgentGroups() {
    return this.args.features.some((feature) => feature.access_by_agent_groups);
  }

  get chatbotAgents() {
    return this.args.features.length === 1
      ? this.args.features[0].chatbot_agents
      : null;
  }

  get featureTogglesDisabled() {
    return this.enabledSetting?.value === false;
  }

  get #soleFeatureSetting() {
    if (this.args.enabledSetting || this.args.features.length !== 1) {
      return null;
    }
    return this.args.features[0].enabled_setting ?? null;
  }

  @action
  toggleExpanded() {
    this._expanded = !this.isExpanded;
  }

  @action
  featureName(feature) {
    if (this.isAutomation) {
      return feature.name;
    }
    return i18n(
      `discourse_ai.features.${this.args.module.module_name}.${feature.name}`
    );
  }

  @action
  transitionToAutomations() {
    this.router.transitionTo("/admin/plugins/automation/automation");
  }

  <template>
    <tr
      class="d-table__row ai-features-module-row
        {{if this.isExpanded '--expanded'}}
        {{if @enabled '--enabled'}}"
      data-module-name={{@module.module_name}}
    >
      <td class="d-table__cell --overview ai-features-module-row__overview">
        <DButton
          class="btn-transparent ai-features-module-row__expand"
          @action={{this.toggleExpanded}}
          @ariaControls={{this.featuresId}}
          @ariaExpanded={{this.isExpanded}}
          @icon={{if this.isExpanded "angle-down" "angle-right"}}
          @translatedLabel={{this.name}}
        />
        <div
          class="d-table__overview-about ai-features-module-row__description"
        >
          {{this.description}}
        </div>
      </td>

      <td class="d-table__cell --detail ai-features-module-row__status">
        <div class="d-table__mobile-label">
          {{i18n "discourse_ai.features.table.status"}}
        </div>
        <div>
          <AiFeaturesStatus
            @label={{this.statusLabel}}
            @status={{this.status}}
          />
          {{#if this.statusSetupLink}}
            <LinkTo
              class="ai-features-module-row__status-note"
              @query={{this.statusSetupLink.query}}
              @route={{this.statusSetupLink.route}}
            >{{this.statusNote}}</LinkTo>
          {{else if this.statusNote}}
            <div class="ai-features-module-row__status-note">
              {{this.statusNote}}
            </div>
          {{else if this.modelSummary}}
            <div
              class="ai-features-module-row__llms"
            >{{this.modelSummary}}</div>
          {{/if}}
        </div>
      </td>

      <td class="d-table__cell --detail ai-features-module-row__enabled">
        {{#if this.showToggle}}
          <div class="d-table__mobile-label">
            {{i18n "discourse_ai.features.table.enabled"}}
          </div>
          <AiFeatureSettingToggle
            @label={{this.toggleLabel}}
            @onChange={{@onChange}}
            @setting={{this.enabledSetting}}
          />
        {{/if}}
      </td>

      <td class="d-table__cell --controls ai-features-module-row__controls">
        {{#if this.isAutomation}}
          <DButton
            class="btn-default btn-small edit"
            @action={{this.transitionToAutomations}}
            @label="discourse_ai.features.edit"
          />
        {{else if this.statusSetupLink}}
          <LinkTo
            class="btn btn-default btn-small edit"
            @query={{this.statusSetupLink.query}}
            @route={{this.statusSetupLink.route}}
          >{{i18n "discourse_ai.features.set_up"}}</LinkTo>
        {{else}}
          <DButton
            class="btn-default btn-small edit"
            @label={{if
              (eq this.status "setup")
              "discourse_ai.features.set_up"
              "discourse_ai.features.edit"
            }}
            @route={{this.settingsRoute}}
            @routeModels={{this.settingsRouteModels}}
          />
        {{/if}}
      </td>
    </tr>

    {{#if this.isExpanded}}
      <tr
        class="ai-features-module-row__features-row"
        data-module-name={{@module.module_name}}
        id={{this.featuresId}}
      >
        <td class="ai-features-module-row__features-cell" colspan="4">
          {{#if this.chatbotAgents}}
            <AiFeaturesChatbotAgents
              @agents={{this.chatbotAgents}}
              @disabled={{this.featureTogglesDisabled}}
              @onChange={{@onChange}}
            />
          {{else if @features.length}}
            <table class="d-table ai-features-module-row__features">
              <thead class="d-table__header">
                <tr class="d-table__row">
                  <th class="d-table__header-cell">
                    {{i18n "discourse_ai.features.table.feature"}}
                  </th>
                  <th class="d-table__header-cell">
                    {{i18n "discourse_ai.features.table.agent"}}
                  </th>
                  <th class="d-table__header-cell">
                    {{i18n "discourse_ai.features.table.llm"}}
                  </th>
                  {{#if this.showGroups}}
                    <th class="d-table__header-cell">
                      {{#if this.accessByAgentGroups}}
                        {{i18n "discourse_ai.features.table.who_can_use"}}
                      {{else}}
                        {{i18n "discourse_ai.features.table.groups"}}
                      {{/if}}
                    </th>
                  {{/if}}
                  {{#if this.showFeatureEnabledColumn}}
                    <th class="d-table__header-cell">
                      {{i18n "discourse_ai.features.table.enabled"}}
                    </th>
                  {{/if}}
                </tr>
              </thead>
              <tbody class="d-table__body">
                {{#each @features as |feature|}}
                  <AiFeaturesFeatureRow
                    @feature={{feature}}
                    @moduleEnabled={{@enabled}}
                    @name={{this.featureName feature}}
                    @onChange={{@onChange}}
                    @showEnabled={{this.showFeatureEnabledColumn}}
                    @showGroups={{this.showGroups}}
                    @toggleDisabled={{this.featureTogglesDisabled}}
                    @whoCanUse={{this.accessByAgentGroups}}
                  />
                {{/each}}
              </tbody>
            </table>
          {{else if this.isAutomation}}
            <p class="ai-features-module-row__empty">
              {{i18n "discourse_ai.features.no_automations"}}
            </p>
          {{/if}}
        </td>
      </tr>
    {{/if}}
  </template>
}
