import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";
import { nodeTypePresenter } from "../../../lib/workflows/node-types";

const NodeTypeItem = <template>
  <button
    type="button"
    class="workflows-node-panel__item"
    style={{@presenter.style}}
    {{on "click" @onClick}}
  >
    <span class="workflows-node-panel__item-icon">
      {{icon @presenter.icon}}
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
        {{icon "chevron-right"}}
      </span>
    {{/if}}
  </button>
</template>;

const OperationItem = <template>
  <button
    type="button"
    class="workflows-node-panel__item"
    style={{@presenter.style}}
    {{on "click" @onClick}}
  >
    <span class="workflows-node-panel__item-icon">
      {{icon @presenter.icon}}
    </span>
    <span class="workflows-node-panel__item-content">
      <span class="workflows-node-panel__item-name">
        {{@presenter.operationLabel @operation}}
      </span>
    </span>
  </button>
</template>;

function presenterFor(nodeType) {
  return nodeType ? nodeTypePresenter(nodeType) : null;
}

export default class NodePanel extends Component {
  @tracked selectedCategory = null;
  @tracked selectedOperationNodeType = null;

  get isSearching() {
    return this.args.searchTerm?.trim().length > 0;
  }

  get categories() {
    const groups = new Map();

    for (const nodeType of this.args.nodeTypes || []) {
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

    return (this.args.nodeTypes || []).filter(
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
  handleKeyDown(event) {
    if (event.key === "Escape") {
      event.stopPropagation();
      this.args.onClose?.();
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div class="workflows-node-panel" {{on "keydown" this.handleKeyDown}}>
      <div class="workflows-node-panel__header">
        {{#if this.showOperations}}
          <DButton
            @action={{this.backFromOperations}}
            @icon="chevron-left"
            class="btn-transparent btn-small workflows-node-panel__back"
          />
          <span
            class="workflows-node-panel__item-icon"
            style={{this.selectedOperationPresenter.style}}
          >
            {{icon this.selectedOperationPresenter.icon}}
          </span>
          <span class="workflows-node-panel__title">
            {{this.selectedOperationPresenter.label}}
          </span>
        {{else if this.showCategoryNodes}}
          <DButton
            @action={{this.backToCategories}}
            @icon="chevron-left"
            class="btn-transparent btn-small workflows-node-panel__back"
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
          {{autoFocus}}
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
                {{category.label}}
              </span>
              <span class="workflows-node-panel__category-arrow">
                {{icon "chevron-right"}}
              </span>
            </button>
          {{/each}}
        {{else if this.showCategoryNodes}}
          {{#each this.categoryNodeTypes as |nodeType|}}
            <NodeTypeItem
              @presenter={{nodeTypePresenter nodeType}}
              @onClick={{fn this.handleNodeItemClick nodeType}}
            />
          {{/each}}
        {{else if this.showOperations}}
          {{#each this.selectedOperationPresenter.operations as |operation|}}
            <OperationItem
              @presenter={{this.selectedOperationPresenter}}
              @operation={{operation.value}}
              @onClick={{fn
                this.selectOperation
                this.selectedOperationNodeType
                operation.value
              }}
            />
          {{/each}}
        {{else if this.showSearchResults}}
          {{#each @nodeTypes as |nodeType|}}
            <NodeTypeItem
              @presenter={{nodeTypePresenter nodeType}}
              @onClick={{fn this.handleNodeItemClick nodeType}}
            />
          {{/each}}
        {{/if}}
      </div>
    </div>
  </template>
}
