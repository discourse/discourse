import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";
import AiCreditBar from "./ai-credit-bar";
import AiDefaultLlmSelector from "./ai-default-llm-selector";
import AiLlmEditor from "./ai-llm-editor";

function isPreseeded(llm) {
  if (llm.id < 0) {
    return true;
  }
}

const FEATURE_USAGE_TYPES = new Set([
  "ai_bot",
  "ai_helper",
  "ai_image_caption",
  "ai_summarization",
  "ai_embeddings_semantic_search",
]);

const RECORD_USAGE_ROUTES = {
  ai_agent: { route: "adminPlugins.show.discourse-ai-agents.edit" },
  automation: {
    route: "adminPlugins.show.automation.edit",
    parentModel: "automation",
  },
  vision_delegate: { route: "adminPlugins.show.discourse-ai-llms.edit" },
};

export function usageRoute(usage) {
  if (!usage?.type) {
    return null;
  }

  if (FEATURE_USAGE_TYPES.has(usage.type)) {
    return usage.id === null || usage.id === undefined
      ? null
      : {
          route: "adminPlugins.show.discourse-ai-features.edit",
          models: [usage.id],
        };
  }

  if (usage.type === "ai_spam") {
    return { route: "adminPlugins.show.discourse-ai-spam" };
  }

  const target = RECORD_USAGE_ROUTES[usage.type];

  if (!target || usage.id === null || usage.id === undefined) {
    return null;
  }

  return {
    route: target.route,
    models: target.parentModel ? [target.parentModel, usage.id] : [usage.id],
  };
}

class UsageItem extends Component {
  get target() {
    return usageRoute(this.args.usage);
  }

  <template>
    {{#if this.target}}
      {{#if this.target.models}}
        <LinkTo @models={{this.target.models}} @route={{this.target.route}}>
          {{@label}}
        </LinkTo>
      {{else}}
        <LinkTo @route={{this.target.route}}>{{@label}}</LinkTo>
      {{/if}}
    {{else}}
      {{@label}}
    {{/if}}
  </template>
}

export default class AiLlmsListEditor extends Component {
  @service adminPluginNavManager;
  @service router;

  get hasLlmElements() {
    return this.args.llms.content.length !== 0;
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

  formatResetDate(dateString) {
    const resetDate = new Date(dateString);
    const options = {
      month: "long",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZone: "UTC",
    };
    return resetDate.toLocaleString(undefined, options);
  }

  @action
  modelDescription(llm) {
    // this is a bit of an odd object, it can be an llm model or a preset model
    // handle both flavors

    // in the case of model
    let key;
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

  @action
  transitionToLlmEditor(llmTemplate) {
    this.router.transitionTo("adminPlugins.show.discourse-ai-llms.new", {
      queryParams: { llmTemplate },
    });
  }

  localizeUsage(usage) {
    if (!usage?.type) {
      return usage?.name || "";
    }

    const key = `discourse_ai.llms.usage.${usage.type}`;
    if (I18n.lookup(key, { ignoreMissing: true })) {
      return i18n(key, { agent: usage.name });
    }

    return usage.name || usage.type;
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.llms.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-llms"
    />
    <section class="ai-llm-list-editor admin-detail">
      {{#if @currentLlm}}
        <AiLlmEditor
          @llms={{@llms}}
          @llmTemplate={{@llmTemplate}}
          @model={{@currentLlm}}
        />
      {{else}}
        <DPageSubheader
          @descriptionLabel={{i18n
            "discourse_ai.llms.preconfigured.description"
          }}
          @learnMoreUrl="https://meta.discourse.org/t/discourse-ai-large-language-model-llm-settings-page/319903"
          @titleLabel={{i18n "discourse_ai.llms.short_title"}}
        />

        <AiDefaultLlmSelector />

        {{#if this.hasLlmElements}}
          <section class="ai-llms-list-editor__configured">
            <DPageSubheader
              @titleLabel={{i18n "discourse_ai.llms.configured.title"}}
            />
            <table class="d-table">
              <thead class="d-table__header">
                <tr>
                  <th>{{i18n "discourse_ai.llms.display_name"}}</th>
                  <th>{{i18n "discourse_ai.llms.provider"}}</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {{#each @llms.content as |llm|}}
                  <tr
                    class="ai-llm-list__row d-table__row"
                    data-llm-id={{llm.name}}
                  >
                    <td class="d-table__cell --overview">

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
                            <li>
                              <UsageItem
                                @label={{this.localizeUsage usage}}
                                @usage={{usage}}
                              />
                            </li>
                          {{/each}}
                        </ul>
                      {{/if}}
                      {{#if llm.llm_credit_allocation}}
                        <div class="ai-llm-list__credit-allocation">
                          <AiCreditBar
                            @allocation={{llm.llm_credit_allocation}}
                          />
                          {{#if llm.llm_credit_allocation.hard_limit_reached}}
                            <div class="alert alert-danger ai-credit-warning">
                              {{dIcon "circle-info"}}
                              {{trustHTML
                                (i18n
                                  "discourse_ai.llms.credit_allocation.hard_limit_warning"
                                  reset_date=(this.formatResetDate
                                    llm.llm_credit_allocation.next_reset_at
                                  )
                                )
                              }}
                            </div>
                          {{else if
                            llm.llm_credit_allocation.soft_limit_reached
                          }}
                            <div class="alert alert-warning ai-credit-warning">
                              {{dIcon "circle-info"}}
                              {{trustHTML
                                (i18n
                                  "discourse_ai.llms.credit_allocation.soft_limit_warning"
                                  percentage=llm.llm_credit_allocation.percentage_remaining
                                )
                              }}
                            </div>
                          {{/if}}
                        </div>
                      {{/if}}
                    </td>
                    <td class="d-table__cell --detail">
                      <div class="d-table__mobile-label">
                        {{i18n "discourse_ai.llms.provider"}}
                      </div>
                      {{i18n
                        (concat "discourse_ai.llms.providers." llm.provider)
                      }}
                    </td>
                    <td class="d-table__cell --controls">
                      <DButton
                        class="btn btn-default btn-small ai-llm-list__edit-button"
                        @label="discourse_ai.llms.edit"
                        @route="adminPlugins.show.discourse-ai-llms.edit"
                        @routeModels={{llm.id}}
                      />
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
                class="ai-llms-list-editor__templates-list-item"
                data-llm-id={{llm.id}}
                @descriptionLabelTranslated={{this.modelDescription llm}}
                @taglineLabel={{concat
                  "discourse_ai.llms.providers."
                  llm.provider
                }}
                @titleLabelTranslated={{llm.name}}
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
