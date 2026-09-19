import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import I18n, { i18n } from "discourse-i18n";
import { nodeTypePresenter } from "../../../lib/workflows/node-types";

const NodeTypeItem = <template>
  <button
    class="workflows-node-panel__item"
    style={{@presenter.style}}
    type="button"
    {{on "click" @onClick}}
  >
    <span class="workflows-node-panel__item-icon">
      {{dIcon @presenter.icon}}
    </span>
    <span class="workflows-node-panel__item-content">
      <span class="workflows-node-panel__item-name">
        {{@presenter.label}}
      </span>
      {{#if @presenter.description}}
        <span class="workflows-node-panel__item-description">
          {{@presenter.description}}
        </span>
      {{/if}}
    </span>
    {{#if @presenter.hasOperations}}
      <span class="workflows-node-panel__item-arrow">
        {{dIcon "chevron-right"}}
      </span>
    {{/if}}
  </button>
</template>;

const OperationItem = <template>
  <button
    class="workflows-node-panel__item"
    style={{@presenter.style}}
    type="button"
    {{on "click" @onClick}}
  >
    <span class="workflows-node-panel__item-icon">
      {{dIcon @presenter.icon}}
    </span>
    <span class="workflows-node-panel__item-content">
      <span class="workflows-node-panel__item-name">
        {{@presenter.operationLabel @operation}}
      </span>
    </span>
    <span class="workflows-node-panel__item-arrow">
      {{dIcon "chevron-right"}}
    </span>
  </button>
</template>;

function presenterFor(nodeType) {
  return nodeType ? nodeTypePresenter(nodeType) : null;
}

export function sortNodeTypesByLabel(nodeTypes) {
  return [...(nodeTypes || [])].sort((left, right) =>
    nodeTypePresenter(left).label.localeCompare(
      nodeTypePresenter(right).label,
      I18n.currentBcp47Locale,
      {
        sensitivity: "base",
      }
    )
  );
}

export function nodeTypesForPalette(nodeTypes) {
  return sortNodeTypesByLabel(
    (nodeTypes || []).filter(
      (nodeType) =>
        nodeType.available !== false && nodeType.palette_visible !== false
    )
  );
}

export default class NodePanel extends Component {
  @tracked selectedCategory = null;
  @tracked selectedOperationNodeType = null;

  get isSearching() {
    return this.args.searchTerm?.trim().length > 0;
  }

  get availableNodeTypes() {
    return nodeTypesForPalette(this.args.nodeTypes);
  }

  get categories() {
    const groups = new Map();

    for (const nodeType of this.availableNodeTypes) {
      const presenter = nodeTypePresenter(nodeType);

      if (!presenter.paletteGroup || groups.has(presenter.paletteGroup.id)) {
        continue;
      }

      groups.set(presenter.paletteGroup.id, {
        ...presenter.paletteGroup,
        label: i18n(presenter.paletteGroup.label_key),
      });
    }

    return [...groups.values()].sort((a, b) => a.order - b.order);
  }

  get categoryNodeTypes() {
    if (!this.selectedCategory) {
      return [];
    }

    return this.availableNodeTypes.filter(
      (nodeType) =>
        nodeTypePresenter(nodeType).paletteGroup?.id ===
        this.selectedCategory.id
    );
  }

  get selectedOperationPresenter() {
    return presenterFor(this.selectedOperationNodeType);
  }

  get showCategories() {
    return !this.isSearching && !this.selectedCategory;
  }

  get showCategoryNodes() {
    return (
      !this.isSearching &&
      this.selectedCategory &&
      !this.selectedOperationNodeType
    );
  }

  get showSearchResults() {
    return this.isSearching && !this.selectedOperationNodeType;
  }

  get showOperations() {
    return !!this.selectedOperationNodeType;
  }

  @action
  handleSearchInput(event) {
    this.selectedOperationNodeType = null;
    this.args.onSearch?.(event.target.value);
  }

  @action
  selectCategory(category) {
    this.selectedCategory = category;
  }

  @action
  backToCategories() {
    this.selectedCategory = null;
    this.selectedOperationNodeType = null;
  }

  @action
  selectOperationNodeType(nodeType) {
    this.selectedOperationNodeType = nodeType;
  }

  @action
  backFromOperations() {
    this.selectedOperationNodeType = null;
  }

  @action
  selectOperation(nodeType, operation) {
    this.args.onSelectNodeType?.(nodeType, operation);
  }

  @action
  handleNodeItemClick(nodeType) {
    if (nodeTypePresenter(nodeType).hasOperations) {
      this.selectedOperationNodeType = nodeType;
    } else {
      this.args.onSelectNodeType?.(nodeType);
    }
  }

  @action
  handleSearchKeyDown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      const firstNodeType = this.availableNodeTypes[0];
      if (this.isSearching && firstNodeType) {
        this.handleNodeItemClick(firstNodeType);
      }
    }
  }

  @action
  handleKeyDown(event) {
    if (event.key === "Escape") {
      event.stopPropagation();
      this.args.onClose?.();
    }
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <div class="workflows-node-panel" {{on "keydown" this.handleKeyDown}}>
      <div class="workflows-node-panel__header">
        {{#if this.showOperations}}
          <DButton
            class="btn-transparent btn-small workflows-node-panel__back"
            @action={{this.backFromOperations}}
            @icon="chevron-left"
          />
          <span
            class="workflows-node-panel__item-icon"
            style={{this.selectedOperationPresenter.style}}
          >
            {{dIcon this.selectedOperationPresenter.icon}}
          </span>
          <span class="workflows-node-panel__title">
            {{this.selectedOperationPresenter.label}}
          </span>
        {{else if this.showCategoryNodes}}
          <DButton
            class="btn-transparent btn-small workflows-node-panel__back"
            @action={{this.backToCategories}}
            @icon="chevron-left"
          />
          <span class="workflows-node-panel__title">
            {{this.selectedCategory.label}}
          </span>
        {{else}}
          <span class="workflows-node-panel__title">
            {{i18n "discourse_workflows.add_node.title"}}
          </span>
        {{/if}}
        <DButton
          class="btn-transparent btn-small workflows-node-panel__close"
          @action={{@onClose}}
          @icon="xmark"
        />
      </div>

      <div class="workflows-node-panel__search">
        {{dIcon "magnifying-glass"}}
        <input
          class="workflows-node-panel__search-input"
          placeholder={{i18n "discourse_workflows.add_node.search"}}
          type="text"
          value={{@searchTerm}}
          {{dAutoFocus}}
          {{on "input" this.handleSearchInput}}
          {{on "keydown" this.handleSearchKeyDown}}
        />
      </div>

      <div class="workflows-node-panel__list">
        {{#if this.showCategories}}
          {{#each this.categories as |category|}}
            <button
              class="workflows-node-panel__category"
              type="button"
              {{on "click" (fn this.selectCategory category)}}
            >
              <span class="workflows-node-panel__category-icon">
                {{dIcon category.icon}}
              </span>
              <span class="workflows-node-panel__category-name">
                {{category.label}}
              </span>
              <span class="workflows-node-panel__category-arrow">
                {{dIcon "chevron-right"}}
              </span>
            </button>
          {{/each}}
        {{else if this.showCategoryNodes}}
          {{#each this.categoryNodeTypes as |nodeType|}}
            <NodeTypeItem
              @onClick={{fn this.handleNodeItemClick nodeType}}
              @presenter={{nodeTypePresenter nodeType}}
            />
          {{/each}}
        {{else if this.showOperations}}
          {{#each this.selectedOperationPresenter.operations as |operation|}}
            <OperationItem
              @onClick={{fn
                this.selectOperation
                this.selectedOperationNodeType
                operation.value
              }}
              @operation={{operation.value}}
              @presenter={{this.selectedOperationPresenter}}
            />
          {{/each}}
        {{else if this.showSearchResults}}
          {{#each this.availableNodeTypes as |nodeType|}}
            <NodeTypeItem
              @onClick={{fn this.handleNodeItemClick nodeType}}
              @presenter={{nodeTypePresenter nodeType}}
            />
          {{/each}}
        {{/if}}
      </div>
    </div>
  </template>
}
