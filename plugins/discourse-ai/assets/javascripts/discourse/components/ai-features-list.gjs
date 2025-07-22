import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
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
        @translatedLabel={{this.expandToggleLabel}}
        @action={{this.toggleExpanded}}
      />
    {{/if}}
  </template>
}

export default class AiFeaturesList extends Component {
  get sortedModules() {
    const modules = this.args.modules?.toArray() || this.args.modules;
    return [...(modules || [])].toSorted((a, b) =>
      (a.module_name || "").localeCompare(b.module_name || "")
    );
  }

  @action
  isSpamModule(aModule) {
    return aModule.module_name === "spam";
  }

  @action
  hasGroups(feature) {
    return this.groupList(feature).length > 0;
  }

  @action
  groupList(feature) {
    const groups = [];
    const groupIds = new Set();
    if (feature.personas) {
      feature.personas.forEach((persona) => {
        if (persona.allowed_groups) {
          persona.allowed_groups.forEach((group) => {
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
    <div class="ai-features-list">
      {{#each this.sortedModules as |module|}}
        <div class="ai-module" data-module-name={{module.module_name}}>
          <div class="ai-module__header">
            <div class="ai-module__module-title">
              <h3>{{i18n
                  (concat "discourse_ai.features." module.module_name ".name")
                }}</h3>
              {{#if (this.isSpamModule module)}}
                <DButton
                  class="edit"
                  @label="discourse_ai.features.edit"
                  @route="adminPlugins.show.discourse-ai-spam"
                />
              {{else}}
                <DButton
                  class="edit"
                  @label="discourse_ai.features.edit"
                  @route="adminPlugins.show.discourse-ai-features.edit"
                  @routeModels={{module.id}}
                />
              {{/if}}
            </div>
            <div>{{i18n
                (concat
                  "discourse_ai.features." module.module_name ".description"
                )
              }}</div>
          </div>

          <div class="admin-section-landing-wrapper ai-feature-cards">
            {{#each module.features as |feature|}}
              <div
                class="admin-section-landing-item ai-feature-card"
                data-feature-name={{feature.name}}
              >
                <div class="admin-section-landing-item__content">
                  <div class="ai-feature-card__feature-name">
                    {{i18n
                      (concat
                        "discourse_ai.features."
                        module.module_name
                        "."
                        feature.name
                      )
                    }}
                    {{#unless feature.enabled}}
                      <span>{{i18n "discourse_ai.features.disabled"}}</span>
                    {{/unless}}
                  </div>
                  <div class="ai-feature-card__persona">
                    <span class="ai-feature-card__label">
                      {{i18n
                        "discourse_ai.features.persona"
                        count=feature.personas.length
                      }}
                    </span>
                    {{#if feature.personas}}
                      <ExpandableList
                        @items={{feature.personas}}
                        @maxItemsToShow={{5}}
                        as |persona index isLastItem|
                      >
                        <DButton
                          class="btn-flat ai-feature-card__persona-button btn-text"
                          @translatedLabel={{concat
                            persona.name
                            (unless (isLastItem index) ", ")
                          }}
                          @route="adminPlugins.show.discourse-ai-personas.edit"
                          @routeModels={{persona.id}}
                        />
                      </ExpandableList>
                    {{else}}
                      <span class="ai-feature-card__label">
                        {{i18n "discourse_ai.features.no_persona"}}
                      </span>
                    {{/if}}
                  </div>
                  <div class="ai-feature-card__llm">
                    {{#if feature.llm_models}}
                      <span class="ai-feature-card__label">
                        {{i18n
                          "discourse_ai.features.llm"
                          count=feature.llm_models.length
                        }}
                      </span>
                    {{/if}}
                    {{#if feature.llm_models}}
                      <ExpandableList
                        @items={{feature.llm_models}}
                        @maxItemsToShow={{5}}
                        as |llm index isLastItem|
                      >
                        <DButton
                          class="btn-flat ai-feature-card__llm-button"
                          @translatedLabel={{concat
                            llm.name
                            (unless (isLastItem index) ", ")
                          }}
                          @route="adminPlugins.show.discourse-ai-llms.edit"
                          @routeModels={{llm.id}}
                        />
                      </ExpandableList>
                    {{else}}
                      <span class="ai-feature-card__label">
                        {{i18n "discourse_ai.features.no_llm"}}
                      </span>
                    {{/if}}
                  </div>
                  {{#unless (this.isSpamModule module)}}
                    {{#if feature.personas}}
                      <div class="ai-feature-card__groups">
                        <span class="ai-feature-card__label">
                          {{i18n "discourse_ai.features.groups"}}
                        </span>
                        {{#if (this.hasGroups feature)}}
                          <ul class="ai-feature-card__item-groups">
                            {{#each (this.groupList feature) as |group|}}
                              <li>{{group.name}}</li>
                            {{/each}}
                          </ul>
                        {{else}}
                          <span class="ai-feature-card__label">
                            {{i18n "discourse_ai.features.no_groups"}}
                          </span>
                        {{/if}}
                      </div>
                    {{/if}}
                  {{/unless}}
                </div>
              </div>
            {{/each}}
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
