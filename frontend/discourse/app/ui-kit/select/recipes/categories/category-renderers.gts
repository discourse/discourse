import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { knownCategories } from "discourse/lib/category-source";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";
import type { CategoryItem, CategoryRecord } from "./category-types.ts";

/** Decodes entities while preserving literal markup as text. */
export function decodeCategoryText(text: string): string {
  return (
    new DOMParser().parseFromString(text.replaceAll("<", "&lt;"), "text/html")
      .body.textContent ?? ""
  );
}

/** Case and accent insensitive category matching. */
export function normalizeCategoryName(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

/** Decodes transformed descriptions without treating their text as markup. */
export function categoryDescription(
  category: CategoryRecord
): string | undefined {
  const text = category.descriptionText;
  if (!text || text === "null") {
    return;
  }
  const decoded = decodeCategoryText(text);
  return decoded.length > 200 ? `${decoded.slice(0, 200)}…` : decoded;
}

/** Builds an engine row while keeping the site's model as the emitted value. */
export function categoryItem(
  category: CategoryRecord,
  descriptions = false
): CategoryItem {
  return {
    id: category.id,
    name: category.name,
    category,
    description: descriptions ? categoryDescription(category) : undefined,
  };
}

/** Narrows the model attached by category sources, including resolved held values. */
function record(item: SelectItem): CategoryRecord | null {
  return (
    (item as CategoryItem).category ??
    (typeof item.id === "number" || typeof item.id === "string"
      ? knownCategories([item.id])[0]
      : undefined) ??
    null
  );
}

/** Narrows shortcut and action labels for templates. */
function name(item: SelectItem): string {
  return String(item.name ?? "");
}

/** Topic counts are confined to options. */
function topicCount(
  category: CategoryRecord | null,
  counts?: boolean,
  countSubcategories?: boolean
) {
  if (!counts) {
    return;
  }
  return countSubcategories ? category?.totalTopicCount : category?.topic_count;
}

/** Renders through the shared badge helper, with counts confined to option rows. */
function badge(
  item: SelectItem,
  ancestors?: boolean,
  counts?: boolean,
  countSubcategories?: boolean
) {
  const category = record(item);
  return categoryLinkHTML(category, {
    allowUncategorized: true,
    hideParent: true,
    ancestors: ancestors ? category?.predecessors : undefined,
    topicCount: topicCount(category, counts, countSubcategories),
    readOnly: item.disabled,
    link: false,
  });
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
  {{#if (and (record @item) (not @item.onSelect))}}
    {{badge @item @ancestors @counts @countSubcategories}}
  {{else}}
    {{name @item}}
  {{/if}}
</template>;
