import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiDefaultLlmSelector from "./ai-default-llm-selector.gjs";
import AiFeaturesList from "./ai-features-list.gjs";

const ALL = "all";
const ENABLED = "enabled";
const NOT_ENABLED = "not enabled";

export default class AiFeatures extends Component {
  @service adminPluginNavManager;
  @service store;

  @tracked filterValue = "";
  @tracked selectedFeatureGroup = ALL;
  @tracked refreshedFeatures = null;

  get features() {
    return this.refreshedFeatures ?? this.args.features;
  }

  get featureGroupOptions() {
    return [
      {
        value: ALL,
        label: i18n("discourse_ai.features.filters.all"),
      },
      {
        value: ENABLED,
        label: i18n("discourse_ai.features.nav.enabled"),
      },
      {
        value: NOT_ENABLED,
        label: i18n("discourse_ai.features.nav.not_enabled"),
      },
    ];
  }

  get isSearching() {
    return this.filterValue.trim() !== "";
  }

  get filteredFeatures() {
    if (!this.features || this.features.length === 0) {
      return [];
    }

    let features = this.features;

    if (this.selectedFeatureGroup === ENABLED) {
      features = features.filter((feature) => feature.module_enabled === true);
    } else if (this.selectedFeatureGroup === NOT_ENABLED) {
      features = features.filter((feature) => feature.module_enabled === false);
    }

    if (this.filterValue && this.filterValue.trim() !== "") {
      const term = this.filterValue.toLowerCase().trim();

      const featureMatches = (module, feature) => {
        try {
          const featureName = i18n(
            `discourse_ai.features.${module.module_name}.${feature.name}`
          ).toLowerCase();
          if (featureName.includes(term)) {
            return true;
          }

          const agents = [
            ...(feature.agents || []),
            ...(feature.chatbot_agents || []),
          ];
          const agentMatches = agents.some((agent) =>
            agent.name?.toLowerCase().includes(term)
          );

          const llmMatches = feature.llm_models?.some((llm) =>
            llm.name?.toLowerCase().includes(term)
          );

          const groupMatches = agents.some((agent) =>
            agent.allowed_groups?.some((group) =>
              group.name?.toLowerCase().includes(term)
            )
          );

          const decisionMatches = feature.decision_model?.display_name
            ?.toLowerCase()
            .includes(term);
          const classificationMatches = feature.classification_model?.model_name
            ?.toLowerCase()
            .includes(term);

          return (
            agentMatches ||
            llmMatches ||
            groupMatches ||
            decisionMatches ||
            classificationMatches
          );
        } catch (error) {
          // eslint-disable-next-line no-console
          console.error(`Error filtering features`, error);
          return false;
        }
      };

      // Filter modules by name or features
      features = features.filter((module) => {
        try {
          const moduleName = i18n(
            `discourse_ai.features.${module.module_name}.name`
          ).toLowerCase();
          if (moduleName.includes(term)) {
            return true;
          }

          return (module.features || []).some((feature) =>
            featureMatches(module, feature)
          );
        } catch (error) {
          // eslint-disable-next-line no-console
          console.error(`Error filtering features`, error);
          return false;
        }
      });

      // For modules that don't match by name, filter features
      features = features
        .map((module) => {
          try {
            const moduleName = i18n(
              `discourse_ai.features.${module.module_name}.name`
            ).toLowerCase();

            // if name matches
            if (moduleName.includes(term)) {
              return module;
            }

            // if no name match
            const matchingFeatures = (module.features || []).filter((feature) =>
              featureMatches(module, feature)
            );

            // recreate with matching features
            return Object.assign({}, module, {
              features: matchingFeatures,
            });
          } catch (error) {
            // eslint-disable-next-line no-console
            console.error(`Error filtering features`, error);
            return module;
          }
        })
        .filter((module) => module.features && module.features.length > 0);
    }

    return features;
  }

  @action
  onFilterChange(event) {
    this.filterValue = event.target?.value || "";
  }

  @action
  onFeatureGroupChange(value) {
    this.selectedFeatureGroup = value;
  }

  @action
  resetAndFocus() {
    this.filterValue = "";
    this.selectedFeatureGroup = ALL;
    document.querySelector(".admin-filter__input")?.focus();
  }

  @action
  async refreshFeatures() {
    const features = await this.store.findAll("ai-feature");
    this.refreshedFeatures = features.content;
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.features.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-features"
    />
    <section class="ai-features admin-detail">
      <DPageSubheader
        @descriptionLabel={{i18n "discourse_ai.features.description"}}
        @titleLabel={{i18n "discourse_ai.features.short_title"}}
      />

      <AiDefaultLlmSelector @onChange={{this.refreshFeatures}} />

      <div class="ai-features__controls">
        <DFilterInput
          class="admin-filter__input"
          placeholder={{i18n "discourse_ai.features.filters.text"}}
          @filterAction={{this.onFilterChange}}
          @icons={{hash left="magnifying-glass"}}
          @value={{this.filterValue}}
        />

        <DFilterControls
          @dropdownOptions={{this.featureGroupOptions}}
          @dropdownValue={{this.selectedFeatureGroup}}
          @onDropdownFilterChange={{this.onFeatureGroupChange}}
          @showNoResults={{false}}
          @showResetButton={{false}}
          @showTextFilter={{false}}
        />
      </div>

      {{#if this.filteredFeatures.length}}
        <AiFeaturesList
          @expandAll={{this.isSearching}}
          @modules={{this.filteredFeatures}}
          @onChange={{this.refreshFeatures}}
        />
      {{else}}
        <div class="ai-features__no-results">
          <h3>{{i18n "discourse_ai.features.filters.no_results"}}</h3>
          <DButton
            class="btn-default"
            @action={{this.resetAndFocus}}
            @icon="arrow-rotate-left"
            @label="discourse_ai.features.filters.reset"
          />
        </div>
      {{/if}}
    </section>
  </template>
}
