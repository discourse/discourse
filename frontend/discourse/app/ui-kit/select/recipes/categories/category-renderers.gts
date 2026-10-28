import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { removeAccents } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";
import type { CategoryItem } from "./category-types.ts";

/** Decodes entities while preserving literal markup as text. */
export function decodeCategoryText(text: string): string {
  return (
    new DOMParser().parseFromString(text.replaceAll("<", "&lt;"), "text/html")
      .body.textContent ?? ""
  );
}

/** Case and accent insensitive category matching. */
export function normalizeCategoryName(text: string): string {
  return removeAccents(text.toLowerCase());
}

/** A row's description: the category's plain-text description, cut to 200 characters. */
export function categoryDescription(category: Category): string | undefined {
  const text = category.descriptionPlainText;
  if (!text || text === "null") {
    return;
  }
  return text.length > 200 ? `${text.slice(0, 200)}…` : text;
}

/** Builds an engine row while keeping the site's model as the emitted value. */
export function categoryItem(
  category: Category,
  descriptions = false
): CategoryItem {
  // Rows come from the site or a search, so the category is saved and has both.
  return {
    id: category.id!,
    name: category.name!,
    category,
    description: descriptions ? categoryDescription(category) : undefined,
  };
}

/**
 * The category a row renders as a badge. Action rows render their label instead, except a
 * family footer, which draws its own category.
 */
function record(item: SelectItem, family?: boolean): Category | undefined {
  if (item.onSelect && !family) {
    return;
  }
  return (
    (item as CategoryItem).category ??
    Category.findById(item.id as number | string)
  );
}

/** Narrows shortcut and action labels for templates. */
function name(item: SelectItem): string {
  return String(item.name ?? "");
}

/** Topic counts are confined to options. */
function topicCount(
  category: Category,
  counts?: boolean,
  countSubcategories?: boolean
) {
  if (!counts) {
    return;
  }
  return countSubcategories ? category.totalTopicCount : category.topic_count;
}

/** Badge content shared by category rows and selections. */
export const CategoryBadge: TemplateOnlyComponent<{
  Args: {
    /** Resolved category or a named shortcut. */
    item: SelectItem;
    /** Includes the category's ancestor badges. */
    ancestors?: boolean;
    /** Displays topic counts on an option. */
    counts?: boolean;
    /** Includes subcategories in the option's topic count. */
    countSubcategories?: boolean;
    /** Draws a family footer: the action row's own category, marked as including subcategories. */
    family?: boolean;
  };
}> = <template>
  {{#let (record @item @family) as |category|}}
    {{#if category}}
      {{dCategoryBadge
        category
        allowUncategorized=true
        ancestors=(if @ancestors category.predecessors)
        hasSubcategories=@family
        hideParent=true
        readOnly=@item.disabled
        topicCount=(topicCount category @counts @countSubcategories)
      }}
    {{else}}
      {{name @item}}
    {{/if}}
  {{/let}}
</template>;
