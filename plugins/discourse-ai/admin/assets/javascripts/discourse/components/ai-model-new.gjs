import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import BackButton from "discourse/components/back-button";
import { escapeExpression } from "discourse/lib/utilities";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import I18n, { i18n } from "discourse-i18n";
import { modelTypes } from "./ai-models-list.gjs";

const LEARN_MORE_URLS = {
  llm: "https://meta.discourse.org/t/discourse-ai-large-language-model-llm-settings-page/319903",
  embedding: "https://meta.discourse.org/t/discourse-ai-embeddings/259603",
  decision:
    "https://meta.discourse.org/t/typesafe-jev-and-other-system-one-decision-models/414738",
};

export default class AiModelNew extends Component {
  @service adminPluginNavManager;
  @service router;

  get types() {
    return modelTypes();
  }

  get selectedType() {
    return this.types.includes(this.args.type) ? this.args.type : null;
  }

  get typeOptions() {
    return this.types.map((type) => ({
      type,
      title: i18n(`discourse_ai.models.type_titles.${type}`),
      description: this.#typeDescription(type),
    }));
  }

  get templates() {
    switch (this.selectedType) {
      case "llm":
        return this.llmTemplates;
      case "embedding":
        return this.embeddingTemplates;
      case "decision":
        return this.decisionTemplates;
      default:
        return [];
    }
  }

  get llmTemplates() {
    const configured = this.args.llms.content;
    const templates = [
      {
        id: "none",
        name: i18n("discourse_ai.llms.preconfigured.fake"),
        tagline: i18n("discourse_ai.llms.providers.fake"),
        description: this.#llmPresetDescription("none"),
      },
    ];

    this.args.llms.resultSetMeta.presets.forEach((preset) => {
      preset.models?.forEach((model) => {
        const isConfigured = configured.some(
          (llm) => llm.provider === preset.provider && llm.name === model.name
        );
        if (isConfigured) {
          return;
        }

        const id = `${preset.id}-${model.name}`;
        templates.push({
          id,
          name: model.display_name,
          tagline: i18n(`discourse_ai.llms.providers.${preset.provider}`),
          description: this.#llmPresetDescription(id),
        });
      });
    });

    return templates;
  }

  get embeddingTemplates() {
    return [
      {
        id: "manual",
        name: i18n("discourse_ai.embeddings.configure_manually"),
        tagline: i18n("discourse_ai.embeddings.providers.fake"),
        description: this.#translatedPresetDescription("embeddings", "manual"),
      },
      ...this.args.embeddings.resultSetMeta.presets.map((preset) => ({
        id: preset.preset_id,
        name: preset.display_name,
        tagline: i18n(`discourse_ai.embeddings.providers.${preset.provider}`),
        description: this.#translatedPresetDescription(
          "embeddings",
          preset.preset_id
        ),
      })),
    ];
  }

  get decisionTemplates() {
    return [
      {
        id: "none",
        name: i18n("discourse_ai.llms.preconfigured.fake"),
        description: this.#translatedPresetDescription(
          "decision_models",
          "none"
        ),
      },
      ...this.args.decisionModels.resultSetMeta.presets.map((preset) => ({
        id: preset.preset_id,
        name: preset.display_name,
        tagline: i18n(
          `discourse_ai.decision_models.providers.${preset.provider}`
        ),
        description: this.#translatedPresetDescription(
          "decision_models",
          preset.preset_id
        ),
      })),
    ];
  }

  @action
  chooseType(type) {
    this.router.transitionTo("adminPlugins.show.discourse-ai-models.new", {
      queryParams: { type },
    });
  }

  @action
  chooseTemplate(template) {
    switch (this.selectedType) {
      case "llm":
        this.router.transitionTo("adminPlugins.show.discourse-ai-llms.new", {
          queryParams: { llmTemplate: template.id },
        });
        break;
      case "embedding":
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-embeddings.new",
          { queryParams: { preset: template.id } }
        );
        break;
      case "decision":
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-decision-models.new",
          {
            queryParams: {
              preset: template.id === "none" ? null : template.id,
            },
          }
        );
        break;
    }
  }

  #typeDescription(type) {
    const description = i18n(`discourse_ai.models.type_descriptions.${type}`);
    const url = LEARN_MORE_URLS[type];
    if (!url) {
      return description;
    }

    return trustHTML(
      `${escapeExpression(description)} ${i18n("learn_more_with_link", { url })}`
    );
  }

  #translatedPresetDescription(scope, id) {
    const key = `discourse_ai.${scope}.preset_descriptions.${id}`;
    return I18n.lookup(key, { ignoreMissing: true }) ? i18n(key) : "";
  }

  #llmPresetDescription(id) {
    const key = `discourse_ai.llms.model_description.${id.replace(
      /[.:\/]/g,
      "-"
    )}`;
    return I18n.lookup(key, { ignoreMissing: true }) ? i18n(key) : "";
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.models.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-models"
    />
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.models.new"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-models/new"
    />
    <section class="ai-model-new admin-detail">
      {{#if this.selectedType}}
        <BackButton
          @label="discourse_ai.models.back_to_types"
          @query={{hash type=null}}
          @route="adminPlugins.show.discourse-ai-models.new"
        />
        <DPageSubheader
          @titleLabel={{i18n
            (concat "discourse_ai.models.templates." this.selectedType)
          }}
        />
        <AdminSectionLandingWrapper class="ai-llms-list-editor__templates-list">
          {{#each this.templates as |template|}}
            <AdminSectionLandingItem
              class="ai-llms-list-editor__templates-list-item"
              data-template-id={{template.id}}
              @descriptionLabelTranslated={{template.description}}
              @taglineLabelTranslated={{template.tagline}}
              @titleLabelTranslated={{template.name}}
            >
              <:buttons as |buttons|>
                <buttons.Default
                  @action={{fn this.chooseTemplate template}}
                  @icon="gear"
                  @label="discourse_ai.llms.preconfigured.button"
                />
              </:buttons>
            </AdminSectionLandingItem>
          {{/each}}
        </AdminSectionLandingWrapper>
      {{else}}
        <BackButton
          @label="discourse_ai.models.back"
          @route="adminPlugins.show.discourse-ai-models.index"
        />
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.models.choose_type"}}
        />
        <AdminSectionLandingWrapper class="ai-llms-list-editor__templates-list">
          {{#each this.typeOptions as |option|}}
            <AdminSectionLandingItem
              class="ai-llms-list-editor__templates-list-item ai-model-new__type"
              data-model-type={{option.type}}
              @descriptionLabelTranslated={{option.description}}
              @titleLabelTranslated={{option.title}}
            >
              <:buttons as |buttons|>
                <buttons.Default
                  @action={{fn this.chooseType option.type}}
                  @label="discourse_ai.models.select_type"
                />
              </:buttons>
            </AdminSectionLandingItem>
          {{/each}}
        </AdminSectionLandingWrapper>
      {{/if}}
    </section>
  </template>
}
