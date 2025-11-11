import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DSelect from "discourse/components/d-select";
import FilterInput from "discourse/components/filter-input";
import { i18n } from "discourse-i18n";
import AiDefaultLlmSelector from "./ai-default-llm-selector";
import AiFeaturesList from "./ai-features-list";

const ALL = "all";
const CONFIGURED = "configured";
const UNCONFIGURED = "unconfigured";

export default class AiFeatures extends Component {
  @service adminPluginNavManager;

  @tracked filterValue = "";
  @tracked selectedFeatureGroup = CONFIGURED;

  constructor() {
    super(...arguments);

    // if there are features but none are configured, show unconfigured
    if (this.args.features?.length > 0) {
      const configuredCount = this.args.features.filter(
        (f) => f.module_enabled === true
      ).length;
      if (configuredCount === 0) {
        this.selectedFeatureGroup = UNCONFIGURED;
      }
    }
  }

  get featureGroupOptions() {
    return [
      { value: ALL, label: i18n("discourse_ai.features.filters.all") },
      {
        value: CONFIGURED,
        label: i18n("discourse_ai.features.nav.configured"),
      },
      {
        value: UNCONFIGURED,
        label: i18n("discourse_ai.features.nav.unconfigured"),
      },
    ];
  }

  get filteredFeatures() {
    if (!this.args.features || this.args.features.length === 0) {
      return [];
    }

    let features = this.args.features;

    if (this.selectedFeatureGroup === CONFIGURED) {
      features = features.filter((feature) => feature.module_enabled === true);
    } else if (this.selectedFeatureGroup === UNCONFIGURED) {
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

          const personaMatches = feature.personas?.some((persona) =>
            persona.name?.toLowerCase().includes(term)
          );

          const llmMatches = feature.llm_models?.some((llm) =>
            llm.name?.toLowerCase().includes(term)
          );

          const groupMatches = feature.personas?.some((persona) =>
            persona.allowed_groups?.some((group) =>
              group.name?.toLowerCase().includes(term)
            )
          );

          return personaMatches || llmMatches || groupMatches;
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
    this.selectedFeatureGroup = CONFIGURED;
    document.querySelector(".admin-filter__input").focus();
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-features"
      @label={{i18n "discourse_ai.features.short_title"}}
    />
    <section class="ai-features admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "discourse_ai.features.short_title"}}
        @descriptionLabel={{i18n "discourse_ai.features.description"}}
        @learnMoreUrl="todo"
      />

      <div class="ai-features__controls">
        <DSelect
          @value={{this.selectedFeatureGroup}}
          @includeNone={{false}}
          @onChange={{this.onFeatureGroupChange}}
          as |select|
        >
          {{#each this.featureGroupOptions as |option|}}
            <select.Option @value={{option.value}}>
              {{option.label}}
            </select.Option>
          {{/each}}
        </DSelect>

        <FilterInput
          placeholder={{i18n "discourse_ai.features.filters.text"}}
          @filterAction={{this.onFilterChange}}
          @value={{this.filterValue}}
          class="admin-filter__input"
          @icons={{hash left="magnifying-glass"}}
        />
      </div>

      <AiDefaultLlmSelector />

      {{#if this.filteredFeatures.length}}
        <AiFeaturesList @modules={{this.filteredFeatures}} />
      {{else}}
        <div class="ai-features__no-results">
          <h3>{{i18n "discourse_ai.features.filters.no_results"}}</h3>
          <DButton
            @icon="arrow-rotate-left"
            @label="discourse_ai.features.filters.reset"
            @action={{this.resetAndFocus}}
            class="btn-default"
          />
        </div>
      {{/if}}
    </section>
  </template>
}
