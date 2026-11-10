import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import GroupLink from "discourse/components/group-link";
import { groupPath } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

class ExpandableList extends Component {
  @tracked isExpanded = false;

  get maxItemsToShow() {
    return this.args.maxItemsToShow ?? 5;
  }

  get hasMore() {
    return this.args.items?.length > this.maxItemsToShow;
  }

  get visibleItems() {
    if (!this.args.items) {
      return [];
    }
    return this.isExpanded
      ? this.args.items
      : this.args.items.slice(0, this.maxItemsToShow);
  }

  get remainingCount() {
    return this.args.items?.length - this.maxItemsToShow;
  }

  get expandToggleLabel() {
    if (this.isExpanded) {
      return i18n("discourse_ai.features.collapse_list");
    } else {
      return i18n("discourse_ai.features.expand_list", {
        count: this.remainingCount,
      });
    }
  }

  @action
  toggleExpanded() {
    this.isExpanded = !this.isExpanded;
  }

  @action
  isLastItem(index) {
    return index === this.visibleItems.length - 1;
  }

  <template>
    {{#each this.visibleItems as |item index|}}
      {{yield item index this.isLastItem}}
    {{/each}}

    {{#if this.hasMore}}
      <DButton
        class="btn-flat ai-expanded-list__toggle-button"
        @action={{this.toggleExpanded}}
        @translatedLabel={{this.expandToggleLabel}}
      />
    {{/if}}
  </template>
}

export default class AiFeatureCard extends Component {
  get showAgentConfiguration() {
    return !this.args.feature.backend || this.args.feature.backend === "agent";
  }

  get backendLabel() {
    return i18n(`discourse_ai.features.backends.${this.args.feature.backend}`);
  }

  @action
  hasGroups(feature) {
    return this.groupList(feature).length > 0;
  }

  @action
  groupList(feature) {
    const groups = [];
    const groupIds = new Set();
    if (feature.agents) {
      feature.agents.forEach((agent) => {
        if (agent.allowed_groups) {
          agent.allowed_groups.forEach((group) => {
            if (!groupIds.has(group.id)) {
              groupIds.add(group.id);
              groups.push(group);
            }
          });
        }
      });
    }
    return groups;
  }

  <template>
    <div
      class="admin-section-landing-item ai-feature-card"
      data-feature-name={{@feature.name}}
    >
      <div class="admin-section-landing-item__content">
        <div class="ai-feature-card__feature-name">
          {{@localizedFeatureName}}
          {{#unless @feature.enabled}}
            <span>{{i18n "discourse_ai.features.disabled"}}</span>
          {{/unless}}
        </div>
        {{#if @feature.backend}}
          <div class="ai-feature-card__backend">
            <span class="ai-feature-card__label">
              {{i18n "discourse_ai.features.backend"}}
            </span>
            {{this.backendLabel}}
          </div>
          {{#if (eq @feature.ready false)}}
            <div class="ai-feature-card__readiness">
              {{i18n "discourse_ai.features.not_configured"}}
            </div>
          {{/if}}
        {{/if}}
        {{#if this.showAgentConfiguration}}
          <div class="ai-feature-card__agent">
            <span class="ai-feature-card__label">
              {{i18n
                "discourse_ai.features.agent"
                count=@feature.agents.length
              }}
            </span>
            {{#if @feature.agents}}
              <ExpandableList
                @items={{@feature.agents}}
                @maxItemsToShow={{5}}
                as |agent index isLastItem|
              >
                <LinkTo
                  class="ai-feature-card__agent-link"
                  @model={{agent.id}}
                  @route="adminPlugins.show.discourse-ai-agents.edit"
                >
                  {{concat agent.name (unless (isLastItem index) ", ")}}
                </LinkTo>
              </ExpandableList>
            {{else}}
              <span class="ai-feature-card__label">
                {{i18n "discourse_ai.features.no_agent"}}
              </span>
            {{/if}}
          </div>
          <div class="ai-feature-card__llm">
            {{#if @feature.llm_models}}
              <span class="ai-feature-card__label">
                {{i18n
                  "discourse_ai.features.llm"
                  count=@feature.llm_models.length
                }}
              </span>
              <ExpandableList
                @items={{@feature.llm_models}}
                @maxItemsToShow={{5}}
                as |llm index isLastItem|
              >
                <LinkTo
                  class="ai-feature-card__llm-link"
                  @model={{llm.id}}
                  @route="adminPlugins.show.discourse-ai-llms.edit"
                >
                  {{concat llm.name (unless (isLastItem index) ", ")}}
                </LinkTo>
              </ExpandableList>
            {{else}}
              <span class="ai-feature-card__label">
                {{i18n "discourse_ai.features.no_llm"}}
              </span>
            {{/if}}
          </div>
        {{else if (eq @feature.backend "decision_model")}}
          {{#if @feature.decision_model}}
            <div class="ai-feature-card__decision-model">
              <span class="ai-feature-card__label">
                {{i18n "discourse_ai.features.decision_model"}}
              </span>
              <LinkTo
                class="ai-feature-card__decision-model-link"
                @model={{@feature.decision_model.id}}
                @route="adminPlugins.show.discourse-ai-decision-models.edit"
              >
                {{@feature.decision_model.display_name}}
              </LinkTo>
            </div>
          {{/if}}
        {{else if (eq @feature.backend "classification_model")}}
          {{#if @feature.classification_model}}
            <div class="ai-feature-card__classification-model">
              <span class="ai-feature-card__label">
                {{i18n "discourse_ai.features.classification_model"}}
              </span>
              <LinkTo
                class="ai-feature-card__classification-model-link"
                @model="all_results"
                @query={{hash filter="ai_sentiment_model_configs"}}
                @route="adminSiteSettingsCategory"
              >
                {{@feature.classification_model.model_name}}
              </LinkTo>
            </div>
          {{/if}}
        {{/if}}
        {{#if @showGroups}}
          {{#if @feature.agents}}
            <div class="ai-feature-card__groups">
              <span class="ai-feature-card__label">
                {{i18n "discourse_ai.features.groups"}}
              </span>
              {{#if (this.hasGroups @feature)}}
                <ul class="ai-feature-card__item-groups">
                  {{#each (this.groupList @feature) as |group|}}
                    <li>
                      <GroupLink
                        class="mention-group"
                        @href={{groupPath group.name}}
                        @name={{group.name}}
                      >
                        {{group.name}}
                      </GroupLink>
                    </li>
                  {{/each}}
                </ul>
              {{else}}
                <span class="ai-feature-card__label">
                  {{i18n "discourse_ai.features.no_groups"}}
                </span>
              {{/if}}
            </div>
          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
