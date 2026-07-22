import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { type ComponentLike } from "@glint/template";
import type { ArgSchema } from "discourse/blocks/types";
import Category from "discourse/models/category";
import CategoryChooserUntyped from "discourse/select-kit/components/category-chooser";
import CategorySelectorUntyped from "discourse/select-kit/components/category-selector";

type CategoryFieldData = {
  /** Current FormKit field value. */
  value: unknown;
  /** Writes a replacement FormKit field value. */
  set: (value: unknown) => void | Promise<void>;
};

// TODO(devxp-typescript-pending): replace `CategoryFieldData` once FormKit
// exports the type of the field data yielded by a custom control.

interface InspectorCategoryFieldSignature {
  /** Category value and argument schema. */
  Args: {
    /** FormKit field data read and updated by the picker. */
    custom: CategoryFieldData;
    /** Canonical block argument schema controlling single or multi mode. */
    schema: ArgSchema;
  };
}

// TODO(devxp-typescript-pending): import these components directly once their
// select-kit implementations export Glint signatures.
const CategoryChooser = CategoryChooserUntyped as unknown as ComponentLike<{
  /** Category chooser arguments. */
  Args: {
    /** Selected category identifier. */
    value: unknown;
    /** Called with the selected category identifier. */
    onChange: (
      /** Selected category identifier, or `null` when cleared. */
      value: number | null
    ) => void;
  };
}>;

// TODO(devxp-typescript-pending): import CategorySelector directly once its
// select-kit implementation exports a Glint signature.
const CategorySelector = CategorySelectorUntyped as unknown as ComponentLike<{
  /** Category selector arguments. */
  Args: {
    /** Selected category models. */
    categories: Category[];
    /** Called with the selected category models. */
    onChange: (
      /** Selected category models. */
      value: Category[]
    ) => void;
  };
}>;

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
export default class InspectorCategoryField extends Component<InspectorCategoryFieldSignature> {
  /** Category models selected by a pipe-delimited field value. */
  @tracked selectedCategories: Category[] = [];

  /** Most recent category refresh, used to serialize tracked writes. */
  #pendingCategoriesRequest: Promise<void> = Promise.resolve();

  /**
   * Creates the category field and resolves an initial multi-value selection.
   *
   * @param owner - Ember owner for the component instance.
   * @param args - Category value and argument schema.
   */
  constructor(owner: Owner, args: InspectorCategoryFieldSignature["Args"]) {
    super(owner, args);
    if (this.isMulti) {
      this.refreshSelectedCategories();
    }
  }

  /** Whether the schema stores multiple category ids. */
  get isMulti(): boolean {
    return this.args.schema?.type === "string";
  }

  /** Category identifiers parsed from the pipe-delimited value. */
  get categoryIds(): string[] {
    const raw = this.args.custom.value;
    if (typeof raw !== "string") {
      return [];
    }
    return raw.split("|").filter(Boolean);
  }

  /** Queues a refresh of selected category models. */
  @action
  refreshSelectedCategories(): void {
    const previousRequest = this.#pendingCategoriesRequest;
    this.#pendingCategoriesRequest =
      this.#updateSelectedCategories(previousRequest);
  }

  /**
   * Commits a single selected category id.
   *
   * @param value - Selected category id, or `null` when cleared.
   */
  @action
  onChangeSingle(value: number | null): void {
    this.args.custom.set(value);
  }

  /**
   * Commits selected categories as a pipe-delimited id string.
   *
   * @param value - Selected category models.
   */
  @action
  onChangeMulti(value: Category[]): void {
    this.args.custom.set((value || []).map(categoryId).join("|"));
  }

  /**
   * Resolves category ids while preserving request write order.
   *
   * @param previousRequest - Earlier refresh whose tracked write must land first.
   */
  async #updateSelectedCategories(
    previousRequest: Promise<void>
  ): Promise<void> {
    // TODO(devxp-typescript-pending): remove the explicit result annotation
    // once `Category.asyncFindByIds` declares its resolved model type.
    const categories: Category[] = await Category.asyncFindByIds(
      this.categoryIds
    );
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

/**
 * Reads a category model's identifier.
 *
 * @param category - Category selected by the author.
 * @returns Category identifier formatted for pipe-delimited storage.
 */
function categoryId(category: Category): string {
  // TODO(devxp-typescript-pending): read `category.id` directly once the core
  // Category model exports that field in its inferred public type.
  const id = Reflect.get(category, "id");
  return typeof id === "string" || typeof id === "number" ? String(id) : "";
}
