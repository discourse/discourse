import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import Category from "discourse/models/category";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import CategorySelector from "discourse/select-kit/components/category-selector";

/**
 * Entity picker for `ui.control: "category-select"`. Switches between
 * single and multi based on the schema's arg type:
 *
 *   - `type: "number"` → single category, rendered with `CategoryChooser`.
 *     The chooser binds directly to the field value (a category id).
 *   - `type: "string"` → multi categories stored as a pipe-separated id
 *     string (e.g. "1|3|7"). Rendered with `CategorySelector`, which
 *     wants an array of `Category` model instances. We resolve the ids
 *     to models asynchronously (matching the admin site-settings
 *     `category-list` pattern at
 *     `frontend/discourse/admin/components/site-settings/category-list.gjs`),
 *     and serialize back to pipe-separated string on change.
 *
 * `@field` is the FormKit-wrapped field object yielded from
 * `<formField.Control as |field|>`: carries `value`, `set`, plus our
 * own InspectorField shape under `@schema` so we can read the original
 * arg type. We pass the InspectorField separately to keep the data
 * path explicit.
 */
export default class InspectorCategoryField extends Component {
  @tracked selectedCategories = [];

  #pendingCategoriesRequest = Promise.resolve();

  constructor() {
    super(...arguments);
    if (this.isMulti) {
      this.refreshSelectedCategories();
    }
  }

  get isMulti() {
    return this.args.schema?.type === "string";
  }

  get categoryIds() {
    const raw = this.args.custom.value;
    if (typeof raw !== "string") {
      return [];
    }
    return raw.split("|").filter(Boolean);
  }

  @action
  refreshSelectedCategories() {
    const previousRequest = this.#pendingCategoriesRequest;
    this.#pendingCategoriesRequest =
      this.#updateSelectedCategories(previousRequest);
  }

  @action
  onChangeSingle(value) {
    this.args.custom.set(value);
  }

  @action
  onChangeMulti(value) {
    this.args.custom.set((value || []).map((c) => c.id).join("|"));
  }

  async #updateSelectedCategories(previousRequest) {
    const categories = await Category.asyncFindByIds(this.categoryIds);
    // Serialise: the previous request's tracked write must land before
    // ours, otherwise rapid value changes can settle out-of-order.
    await previousRequest;
    this.selectedCategories = categories;
  }

  <template>
    {{#if this.isMulti}}
      <div {{didUpdate this.refreshSelectedCategories @custom.value}}>
        <CategorySelector
          @categories={{this.selectedCategories}}
          @onChange={{this.onChangeMulti}}
        />
      </div>
    {{else}}
      <CategoryChooser
        @value={{@custom.value}}
        @onChange={{this.onChangeSingle}}
      />
    {{/if}}
  </template>
}
