import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiDefaultLlmSelector from "./ai-default-llm-selector";
import AiFeaturesList from "./ai-features-list";

const ALL = "all";
const ENABLED = "enabled";
const NOT_ENABLED = "not enabled";

export default class AiFeatures extends Component {
  @service adminPluginNavManager;
  @service store;

  @tracked filterValue = "";
  @tracked selectedFeatureGroup = ENABLED;
  @tracked refreshedFeatures = null;

  constructor() {
    super(...arguments);

    // if there are features but none are configured, show unconfigured
    if (this.features?.length > 0) {
      const configuredCount = this.features.filter(
        (f) => f.module_enabled === true
      ).length;
      if (configuredCount === 0) {
        this.selectedFeatureGroup = NOT_ENABLED;
      }
    }
  }

  get features() {
    return this.refreshedFeatures ?? this.args.features;
  }

  get featureGroupOptions() {
    return [
      { value: ALL, label: i18n("discourse_ai.features.filters.all") },
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

          const agentMatches = feature.agents?.some((agent) =>
            agent.name?.toLowerCase().includes(term)
          );

          const llmMatches = feature.llm_models?.some((llm) =>
            llm.name?.toLowerCase().includes(term)
          );

          const groupMatches = feature.agents?.some((agent) =>
            agent.allowed_groups?.some((group) =>
              group.name?.toLowerCase().includes(term)
            )
          );

          return agentMatches || llmMatches || groupMatches;
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
    this.selectedFeatureGroup = ENABLED;
    document.querySelector(".admin-filter__input").focus();
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
        @learnMoreUrl="todo"
        @titleLabel={{i18n "discourse_ai.features.short_title"}}
      />

      <div class="ai-features__controls">
        <DNativeSelect
          @includeNone={{false}}
          @onChange={{this.onFeatureGroupChange}}
          @value={{this.selectedFeatureGroup}}
          as |select|
        >
          {{#each this.featureGroupOptions as |option|}}
            <select.Option @value={{option.value}}>
              {{option.label}}
            </select.Option>
          {{/each}}
        </DNativeSelect>

        <DFilterInput
          class="admin-filter__input"
          placeholder={{i18n "discourse_ai.features.filters.text"}}
          @filterAction={{this.onFilterChange}}
          @icons={{hash left="magnifying-glass"}}
          @value={{this.filterValue}}
        />
      </div>

      <AiDefaultLlmSelector @onChange={{this.refreshFeatures}} />

      {{#if this.filteredFeatures.length}}
        <AiFeaturesList @modules={{this.filteredFeatures}} />
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
