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

/** Decodes transformed descriptions without treating their text as markup. */
export function categoryDescription(category: Category): string | undefined {
  const text = category.descriptionText;
  if (!text || text === "null") {
    return;
  }
  const decoded = decodeCategoryText(text);
  return decoded.length > 200 ? `${decoded.slice(0, 200)}…` : decoded;
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

/** The category a row renders as a badge; action rows render their label instead. */
function record(item: SelectItem): Category | undefined {
  if (item.onSelect) {
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
  };
}> = <template>
  {{#let (record @item) as |category|}}
    {{#if category}}
      {{dCategoryBadge
        category
        allowUncategorized=true
        ancestors=(if @ancestors category.predecessors)
        hideParent=true
        readOnly=@item.disabled
        topicCount=(topicCount category @counts @countSubcategories)
      }}
    {{else}}
      {{name @item}}
    {{/if}}
  {{/let}}
</template>;
