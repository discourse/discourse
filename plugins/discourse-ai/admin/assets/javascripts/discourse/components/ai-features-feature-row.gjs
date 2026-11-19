import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import GroupLink from "discourse/components/group-link";
import getURL from "discourse/lib/get-url";
import { groupPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import { enabledSettingControl } from "../lib/ai-feature-enabled-setting.js";
import { setupLink } from "../lib/ai-feature-setup-links.js";
import AiAutomaticImageTools from "./ai-automatic-image-tools.gjs";
import AiFeatureAgentGroups from "./ai-feature-agent-groups.gjs";
import AiFeatureSettingToggle from "./ai-feature-setting-toggle.gjs";
import AiFeaturesStatus from "./ai-features-status.gjs";

export default class AiFeaturesFeatureRow extends Component {
  get usesAgent() {
    const { feature } = this.args;
    return (
      !feature.agentless && (!feature.backend || feature.backend === "agent")
    );
  }

  get backendLabel() {
    return i18n(`discourse_ai.features.backends.${this.args.feature.backend}`);
  }

  get groups() {
    const groups = new Map();
    this.args.feature.agents?.forEach((agent) =>
      agent.allowed_groups?.forEach((group) => groups.set(group.id, group))
    );
    return [...groups.values()];
  }

  get editableAgent() {
    const { feature } = this.args;
    return feature.access_by_agent_groups && feature.agents?.length === 1
      ? feature.agents[0]
      : null;
  }

  /**
   * Something that needs setup is not running, so it offers "Set up" rather than
   * a switch that would suggest otherwise.
   */
  get showToggle() {
    return this.control === "toggle" && this.status !== "setup";
  }

  /**
   * Where to try the feature once it is on, as registered by the plugin that
   * provides it.
   */
  get entryPoint() {
    const { feature } = this.args;
    return feature.entry_point &&
      feature.enabled &&
      this.args.moduleEnabled !== false
      ? feature.entry_point
      : null;
  }

  get entryPointUrl() {
    return getURL(this.entryPoint.path);
  }

  get control() {
    return enabledSettingControl(this.args.feature.enabled_setting);
  }

  /**
   * Features without their own setting follow their module, so they only get a
   * status when they are off while the module is on, or cannot be enabled yet.
   */
  get status() {
    if (this.control === "setup" || this.args.feature.needs_setup) {
      return "setup";
    }
    if (this.args.moduleEnabled !== false && !this.args.feature.enabled) {
      return "off";
    }
    return null;
  }

  get statusLabel() {
    return i18n(
      this.status === "setup"
        ? "discourse_ai.features.status.needs_setup"
        : `discourse_ai.features.status.${this.status}`
    );
  }

  get featureSetupLink() {
    return setupLink(this.args.feature.needs_setup);
  }

  get setupNote() {
    const noteKey = this.args.feature.needs_setup;
    return noteKey && i18n(`discourse_ai.features.status_notes.${noteKey}`);
  }

  get toggleLabel() {
    return i18n("discourse_ai.features.toggle", { name: this.args.name });
  }

  <template>
    <tr
      class="d-table__row ai-features-feature-row"
      data-feature-name={{@feature.name}}
    >
      <td class="d-table__cell --overview ai-features-feature-row__name">
        {{@name}}
        {{#if @feature.automatic_image_tools}}
          <AiAutomaticImageTools @tools={{@feature.automatic_image_tools}} />
        {{/if}}
        {{#if this.entryPoint}}
          <a
            class="btn btn-default btn-small ai-features-feature-row__entry-point"
            href={{this.entryPointUrl}}
          >{{i18n this.entryPoint.label}}</a>
        {{/if}}
      </td>

      <td class="d-table__cell --detail ai-features-feature-row__agent">
        <div class="d-table__mobile-label">
          {{i18n "discourse_ai.features.table.agent"}}
        </div>
        <div>
          {{#if @feature.agentless_note}}
            <span class="ai-features-feature-row__empty">
              {{i18n
                (concat
                  "discourse_ai.features.agentless_notes."
                  @feature.agentless_note
                )
              }}
            </span>
          {{else if this.usesAgent}}
            {{#each @feature.agents as |agent|}}
              <LinkTo
                class="ai-features-feature-row__agent-link"
                @model={{agent.id}}
                @route="adminPlugins.show.discourse-ai-agents.edit"
              >{{agent.name}}</LinkTo>
            {{else}}
              <span class="ai-features-feature-row__empty">
                {{i18n "discourse_ai.features.no_agent"}}
              </span>
            {{/each}}
          {{else if (eq @feature.backend "decision_model")}}
            {{#if @feature.decision_model}}
              <LinkTo
                class="ai-features-feature-row__decision-model-link"
                @model={{@feature.decision_model.id}}
                @route="adminPlugins.show.discourse-ai-decision-models.edit"
              >{{@feature.decision_model.display_name}}</LinkTo>
            {{/if}}
          {{else if @feature.classification_model}}
            <LinkTo
              class="ai-features-feature-row__classification-model-link"
              @model="all_results"
              @query={{hash filter="ai_sentiment_model_configs"}}
              @route="adminSiteSettingsCategory"
            >{{@feature.classification_model.model_name}}</LinkTo>
          {{/if}}
          {{#if @feature.backend}}
            <div class="ai-features-feature-row__backend">
              {{this.backendLabel}}
              {{#if (eq @feature.ready false)}}
                ·
                <span class="ai-features-feature-row__not-configured">
                  {{i18n "discourse_ai.features.not_configured"}}
                </span>
              {{/if}}
            </div>
          {{/if}}
        </div>
      </td>

      <td class="d-table__cell --detail ai-features-feature-row__llm">
        <div class="d-table__mobile-label">
          {{i18n "discourse_ai.features.table.llm"}}
        </div>
        <div>
          {{#if this.usesAgent}}
            {{#each @feature.llm_models as |llm|}}
              <LinkTo
                class="ai-features-feature-row__llm-link"
                @model={{llm.id}}
                @route="adminPlugins.show.discourse-ai-llms.edit"
              >{{llm.name}}</LinkTo>
            {{else}}
              <span class="ai-features-feature-row__empty">
                {{i18n "discourse_ai.features.no_llm"}}
              </span>
            {{/each}}
            {{#if @feature.decision_model}}
              <div class="ai-features-feature-row__decision-model">
                <span class="ai-features-feature-row__decision-model-label">
                  {{i18n "discourse_ai.features.decision_model"}}
                </span>
                <LinkTo
                  class="ai-features-feature-row__decision-model-link"
                  @model={{@feature.decision_model.id}}
                  @route="adminPlugins.show.discourse-ai-decision-models.edit"
                >{{@feature.decision_model.display_name}}</LinkTo>
              </div>
            {{/if}}
          {{/if}}
        </div>
      </td>

      {{#if @showGroups}}
        <td class="d-table__cell --detail ai-features-feature-row__groups">
          <div class="d-table__mobile-label">
            {{#if @feature.access_by_agent_groups}}
              {{i18n "discourse_ai.features.table.who_can_use"}}
            {{else}}
              {{i18n "discourse_ai.features.table.groups"}}
            {{/if}}
          </div>
          {{#if this.editableAgent}}
            <AiFeatureAgentGroups
              @agent={{this.editableAgent}}
              @featureName={{@name}}
              @onChange={{@onChange}}
              @sharedWith={{@feature.shared_with}}
            />
          {{else if @whoCanUse}}
            {{! groups do not gate features used automatically }}
          {{else if @feature.agents}}
            <ul class="ai-features-feature-row__group-list">
              {{#each this.groups as |group|}}
                <li>
                  <GroupLink
                    class="mention-group"
                    @href={{groupPath group.name}}
                    @name={{group.name}}
                  >{{group.name}}</GroupLink>
                </li>
              {{else}}
                <li class="ai-features-feature-row__empty">
                  {{i18n "discourse_ai.features.no_groups"}}
                </li>
              {{/each}}
            </ul>
          {{/if}}
        </td>
      {{/if}}

      {{#if @showEnabled}}
        <td class="d-table__cell --detail ai-features-feature-row__enabled">
          {{#if this.showToggle}}
            <div class="d-table__mobile-label">
              {{i18n "discourse_ai.features.table.enabled"}}
            </div>
            <AiFeatureSettingToggle
              @disabled={{@toggleDisabled}}
              @label={{this.toggleLabel}}
              @onChange={{@onChange}}
              @setting={{@feature.enabled_setting}}
            />
          {{else if this.status}}
            <div class="d-table__mobile-label">
              {{i18n "discourse_ai.features.table.enabled"}}
            </div>
            <AiFeaturesStatus
              @label={{this.statusLabel}}
              @status={{this.status}}
            />
            {{#if this.featureSetupLink}}
              <LinkTo
                class="ai-features-feature-row__setup-note"
                @query={{this.featureSetupLink.query}}
                @route={{this.featureSetupLink.route}}
              >{{this.setupNote}}</LinkTo>
            {{else if this.setupNote}}
              <div class="ai-features-feature-row__setup-note">
                {{this.setupNote}}
              </div>
            {{/if}}
          {{/if}}
        </td>
      {{/if}}
    </tr>
  </template>
}
