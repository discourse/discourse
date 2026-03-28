import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  nodeTypeDescription,
  nodeTypeIcon,
  nodeTypeLabel,
  nodeTypeStyle,
} from "../../../lib/workflows/node-types";

const NodeTypeItem = <template>
  <button
    type="button"
    class="workflows-node-panel__item"
    style={{nodeTypeStyle @nodeType}}
    {{on "click" @onClick}}
  >
    <span class="workflows-node-panel__item-icon">
      {{icon (nodeTypeIcon @nodeType)}}
    </span>
    <span class="workflows-node-panel__item-content">
      <span class="workflows-node-panel__item-name">
        {{nodeTypeLabel @nodeType}}
      </span>
      {{#if (nodeTypeDescription @nodeType)}}
        <span class="workflows-node-panel__item-description">
          {{nodeTypeDescription @nodeType}}
        </span>
      {{/if}}
    </span>
  </button>
</template>;

const CATEGORIES = [
  {
    id: "discourse_triggers",
    icon: "discourse-other-tab",
    identifiers: [
      "trigger:topic_closed",
      "trigger:post_created",
      "trigger:topic_created",
      "trigger:topic_category_changed",
      "trigger:stale_topic",
    ],
  },
  {
    id: "triggers",
    icon: "bolt",
    identifiers: ["trigger:webhook", "trigger:manual", "trigger:schedule"],
  },
  {
    id: "discourse_actions",
    icon: "discourse-other-tab",
    identifiers: [
      "action:append_tags",
      "action:award_badge",
      "action:create_post",
      "action:create_topic",
      "action:fetch_topic",
      "action:list_topics",
    ],
  },
  {
    id: "ai",
    icon: "robot",
    identifiers: ["action:ai_agent"],
  },
  {
    id: "data",
    icon: "table",
    identifiers: ["action:set_fields", "action:data_table"],
  },
  {
    id: "core",
    icon: "code",
    identifiers: ["action:code", "action:http_request"],
  },
  {
    id: "flow",
    icon: "arrows-split-up-and-left",
    identifiers: [
      "condition:if",
      "condition:filter",
      "action:split_out",
      "core:loop_over_items",
    ],
  },
  {
    id: "human_review",
    icon: "user-check",
    identifiers: ["action:chat_approval"],
  },
];

export default class NodePanel extends Component {
  @tracked selectedCategory = null;

  get isSearching() {
    return this.args.searchTerm?.trim().length > 0;
  }

  get categories() {
    const available = new Set(
      (this.args.nodeTypes || []).map((nt) => nt.identifier)
    );
    return CATEGORIES.filter((cat) =>
      cat.identifiers.some((id) => available.has(id))
    );
  }

  get categoryNodeTypes() {
    if (!this.selectedCategory) {
      return [];
    }
    const ids = new Set(this.selectedCategory.identifiers);
    return (this.args.nodeTypes || []).filter((nt) => ids.has(nt.identifier));
  }

  get showCategories() {
    return !this.isSearching && !this.selectedCategory;
  }

  get showCategoryNodes() {
    return !this.isSearching && this.selectedCategory;
  }

  get showSearchResults() {
    return this.isSearching;
  }

  @action
  handleSearchInput(event) {
    this.args.onSearch?.(event.target.value);
  }

  @action
  selectCategory(category) {
    this.selectedCategory = category;
  }

  @action
  backToCategories() {
    this.selectedCategory = null;
  }

  @action
  handleKeyDown(event) {
    if (event.key === "Escape") {
      event.stopPropagation();
      this.args.onClose?.();
    }
  }

  @action
  focusSearch(element) {
    element.focus();
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div class="workflows-node-panel" {{on "keydown" this.handleKeyDown}}>
      <div class="workflows-node-panel__header">
        {{#if this.showCategoryNodes}}
          <DButton
            @action={{this.backToCategories}}
            @icon="chevron-left"
            class="btn-transparent btn-small workflows-node-panel__back"
          />
          <span class="workflows-node-panel__title">
            {{i18n
              (concat
                "discourse_workflows.add_node.categories."
                this.selectedCategory.id
              )
            }}
          </span>
        {{else}}
          <span class="workflows-node-panel__title">
            {{i18n "discourse_workflows.add_node.title"}}
          </span>
        {{/if}}
        <DButton
          @action={{@onClose}}
          @icon="xmark"
          class="btn-transparent btn-small workflows-node-panel__close"
        />
      </div>

      <div class="workflows-node-panel__search">
        {{icon "magnifying-glass"}}
        <input
          type="text"
          placeholder={{i18n "discourse_workflows.add_node.search"}}
          value={{@searchTerm}}
          class="workflows-node-panel__search-input"
          {{didInsert this.focusSearch}}
          {{on "input" this.handleSearchInput}}
        />
      </div>

      <div class="workflows-node-panel__list">
        {{#if this.showCategories}}
          {{#each this.categories as |category|}}
            <button
              type="button"
              class="workflows-node-panel__category"
              {{on "click" (fn this.selectCategory category)}}
            >
              <span class="workflows-node-panel__category-icon">
                {{icon category.icon}}
              </span>
              <span class="workflows-node-panel__category-name">
                {{i18n
                  (concat
                    "discourse_workflows.add_node.categories." category.id
                  )
                }}
              </span>
              <span class="workflows-node-panel__category-arrow">
                {{icon "chevron-right"}}
              </span>
            </button>
          {{/each}}
        {{else if this.showCategoryNodes}}
          {{#each this.categoryNodeTypes as |nodeType|}}
            <NodeTypeItem
              @nodeType={{nodeType}}
              @onClick={{fn @onSelectNodeType nodeType}}
            />
          {{/each}}
        {{else if this.showSearchResults}}
          {{#each @nodeTypes as |nodeType|}}
            <NodeTypeItem
              @nodeType={{nodeType}}
              @onClick={{fn @onSelectNodeType nodeType}}
            />
          {{/each}}
        {{/if}}
      </div>
    </div>
  </template>
}
