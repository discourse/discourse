import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import I18n, { i18n } from "discourse-i18n";
import AdminSectionLandingItem from "admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "admin/components/admin-section-landing-wrapper";
import DTooltip from "float-kit/components/d-tooltip";
import AiLlmEditor from "./ai-llm-editor";

function isPreseeded(llm) {
  if (llm.id < 0) {
    return true;
  }
}

export default class AiLlmsListEditor extends Component {
  @service adminPluginNavManager;
  @service router;

  @action
  modelDescription(llm) {
    // this is a bit of an odd object, it can be an llm model or a preset model
    // handle both flavors

    // in the case of model
    let key = "";
    if (typeof llm.id === "number") {
      key = `${llm.provider}-${llm.name}`;
    } else {
      // case of preset
      key = llm.id.replace(/[.:\/]/g, "-");
    }

    key = `discourse_ai.llms.model_description.${key}`;
    if (I18n.lookup(key, { ignoreMissing: true })) {
      return i18n(key);
    }
    return "";
  }

  @action
  preseededDescription(llm) {
    if (isPreseeded(llm)) {
      return i18n("discourse_ai.llms.preseeded_model_description", {
        model: llm.name,
      });
    }
  }

  sanitizedTranslationKey(id) {
    return id.replace(/\./g, "-");
  }

  get hasLlmElements() {
    return this.args.llms.length !== 0;
  }

  get preconfiguredTitle() {
    if (this.hasLlmElements) {
      return "discourse_ai.llms.preconfigured.title";
    } else {
      return "discourse_ai.llms.preconfigured.title_no_llms";
    }
  }

  get preConfiguredLlms() {
    const options = [
      {
        id: "none",
        name: i18n("discourse_ai.llms.preconfigured.fake"),
        provider: "fake",
      },
    ];

    const llmsContent = this.args.llms.content.map((llm) => ({
      provider: llm.provider,
      name: llm.name,
    }));

    this.args.llms.resultSetMeta.presets.forEach((llm) => {
      if (llm.models) {
        llm.models.forEach((model) => {
          const id = `${llm.id}-${model.name}`;
          const isConfigured = llmsContent.some(
            (content) =>
              content.provider === llm.provider && content.name === model.name
          );

          if (!isConfigured) {
            options.push({
              id,
              name: model.display_name,
              provider: llm.provider,
            });
          }
        });
      }
    });

    return options;
  }

  @action
  transitionToLlmEditor(llmTemplate) {
    this.router.transitionTo("adminPlugins.show.discourse-ai-llms.new", {
      queryParams: { llmTemplate },
    });
  }

  localizeUsage(usage) {
    return i18n(`discourse_ai.llms.usage.${usage.type}`, {
      persona: usage.name,
    });
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-llms"
      @label={{i18n "discourse_ai.llms.short_title"}}
    />
    <section class="ai-llm-list-editor admin-detail">
      {{#if @currentLlm}}
        <AiLlmEditor
          @model={{@currentLlm}}
          @llms={{@llms}}
          @llmTemplate={{@llmTemplate}}
        />
      {{else}}
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.llms.short_title"}}
          @descriptionLabel={{i18n
            "discourse_ai.llms.preconfigured.description"
          }}
          @learnMoreUrl="https://meta.discourse.org/t/discourse-ai-large-language-model-llm-settings-page/319903"
        />
        {{#if this.hasLlmElements}}
          <section class="ai-llms-list-editor__configured">
            <DPageSubheader
              @titleLabel={{i18n "discourse_ai.llms.configured.title"}}
            />
            <table class="d-admin-table">
              <thead>
                <tr>
                  <th>{{i18n "discourse_ai.llms.display_name"}}</th>
                  <th>{{i18n "discourse_ai.llms.provider"}}</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {{#each @llms as |llm|}}
                  <tr
                    data-llm-id={{llm.name}}
                    class="ai-llm-list__row d-admin-row__content"
                  >
                    <td class="d-admin-row__overview">

                      <div class="ai-llm-list__name">
                        <strong>
                          {{llm.display_name}}
                        </strong>
                      </div>
                      <div class="ai-llm-list__description">
                        {{this.modelDescription llm}}
                        {{this.preseededDescription llm}}
                      </div>
                      {{#if llm.used_by}}
                        <ul class="ai-llm-list-editor__usages">
                          {{#each llm.used_by as |usage|}}
                            <li>{{this.localizeUsage usage}}</li>
                          {{/each}}
                        </ul>
                      {{/if}}
                    </td>
                    <td class="d-admin-row__detail">
                      <div class="d-admin-row__mobile-label">
                        {{i18n "discourse_ai.llms.provider"}}
                      </div>
                      {{i18n
                        (concat "discourse_ai.llms.providers." llm.provider)
                      }}
                    </td>
                    <td class="d-admin-row__controls">
                      {{#if (isPreseeded llm)}}
                        <DTooltip class="ai-llm-list__edit-disabled-tooltip">
                          <:trigger>
                            <DButton
                              class="btn btn-default btn-small disabled"
                              @label="discourse_ai.llms.edit"
                            />
                          </:trigger>
                          <:content>
                            {{i18n "discourse_ai.llms.seeded_warning"}}
                          </:content>
                        </DTooltip>
                      {{else}}
                        <DButton
                          class="btn btn-default btn-small ai-llm-list__delete-button"
                          @label="discourse_ai.llms.edit"
                          @route="adminPlugins.show.discourse-ai-llms.edit"
                          @routeModels={{llm.id}}
                        />
                      {{/if}}
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </section>
        {{/if}}
        <section class="ai-llms-list-editor__templates">
          <DPageSubheader @titleLabel={{i18n this.preconfiguredTitle}} />
          <AdminSectionLandingWrapper
            class="ai-llms-list-editor__templates-list"
          >
            {{#each this.preConfiguredLlms as |llm|}}
              <AdminSectionLandingItem
                @titleLabelTranslated={{llm.name}}
                @descriptionLabelTranslated={{this.modelDescription llm}}
                @taglineLabel={{concat
                  "discourse_ai.llms.providers."
                  llm.provider
                }}
                data-llm-id={{llm.id}}
                class="ai-llms-list-editor__templates-list-item"
              >
                <:buttons as |buttons|>
                  <buttons.Default
                    @action={{fn this.transitionToLlmEditor llm.id}}
                    @icon="gear"
                    @label="discourse_ai.llms.preconfigured.button"
                  />
                </:buttons>
              </AdminSectionLandingItem>
            {{/each}}
          </AdminSectionLandingWrapper>
        </section>
      {{/if}}
    </section>
  </template>
}
