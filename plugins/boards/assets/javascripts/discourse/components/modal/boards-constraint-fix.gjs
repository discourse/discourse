import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import Category from "discourse/models/category";
import { eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

function includes(arr, item) {
  return arr.includes(item);
}

export default class BoardsConstraintFix extends Component {
  @tracked selectedCategoryId = null;
  @tracked selectedTagNames = [];

  constructor() {
    super(...arguments);
    const { mismatches, topic } = this.args.model;

    if (mismatches.needsCategory && mismatches.boardCategoryIds.length === 1) {
      this.selectedCategoryId = mismatches.boardCategoryIds[0];
    }

    if (!mismatches.needsCategory) {
      this.selectedCategoryId = topic.category_id;
    }
  }

  get categoryOptions() {
    const { mismatches } = this.args.model;
    if (!mismatches.needsCategory) {
      return [];
    }
    return mismatches.boardCategoryIds.map((id) => {
      const cat = Category.findById(id);
      return { id, name: cat?.name || `Category ${id}` };
    });
  }

  get tagOptions() {
    const { mismatches } = this.args.model;
    if (!mismatches.needsTags) {
      return [];
    }
    return mismatches.boardTagNames;
  }

  get canSave() {
    const { mismatches } = this.args.model;
    if (mismatches.needsCategory && !this.selectedCategoryId) {
      return false;
    }
    if (mismatches.needsTags && this.selectedTagNames.length === 0) {
      return false;
    }
    return true;
  }

  @action
  selectCategory(categoryId) {
    this.selectedCategoryId = categoryId;
  }

  @action
  toggleTag(tagName) {
    if (this.selectedTagNames.includes(tagName)) {
      this.selectedTagNames = this.selectedTagNames.filter(
        (t) => t !== tagName
      );
    } else {
      this.selectedTagNames = [...this.selectedTagNames, tagName];
    }
  }

  @action
  confirm() {
    const result = {};
    const { mismatches } = this.args.model;

    if (mismatches.needsCategory) {
      result.category_id = this.selectedCategoryId;
    }
    if (mismatches.needsTags) {
      result.tag_names = this.selectedTagNames;
    }

    this.args.model.onConfirm(result);
    this.args.closeModal();
  }

  @action
  cancel() {
    this.args.model.onCancel?.();
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{this.cancel}}
      @title={{i18n "boards.board.constraint_fix_title"}}
      class="discourse-boards-constraint-fix-modal"
    >
      <:body>
        <p class="discourse-boards-constraint-fix__description">
          {{i18n "boards.board.constraint_fix_description"}}
        </p>

        {{#if @model.mismatches.needsCategory}}
          <div class="discourse-boards-constraint-fix__field">
            <label>{{i18n "boards.board.constraint_fix_category"}}</label>
            <div class="discourse-boards-constraint-fix__options">
              {{#each this.categoryOptions as |cat|}}
                <DButton
                  @action={{fn this.selectCategory cat.id}}
                  @translatedLabel={{cat.name}}
                  class={{if
                    (eq this.selectedCategoryId cat.id)
                    "btn-primary discourse-boards-constraint-fix__option--selected"
                    "btn-default"
                  }}
                  data-category-id={{cat.id}}
                />
              {{/each}}
            </div>
          </div>
        {{/if}}

        {{#if @model.mismatches.needsTags}}
          <div class="discourse-boards-constraint-fix__field">
            <label>{{i18n "boards.board.constraint_fix_tags"}}</label>
            <div class="discourse-boards-constraint-fix__options">
              {{#each this.tagOptions as |tagName|}}
                <DButton
                  @action={{fn this.toggleTag tagName}}
                  @translatedLabel={{tagName}}
                  class={{if
                    (includes this.selectedTagNames tagName)
                    "btn-primary discourse-boards-constraint-fix__option--selected"
                    "btn-default"
                  }}
                  data-tag-name={{tagName}}
                />
              {{/each}}
            </div>
          </div>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          @action={{this.confirm}}
          @label="boards.board.constraint_fix_confirm"
          @disabled={{not this.canSave}}
          class="btn-primary"
        />
        <DButton @action={{this.cancel}} @label="cancel" class="btn-flat" />
      </:footer>
    </DModal>
  </template>
}
