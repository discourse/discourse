import type { TemplateOnlyComponent } from "@ember/component/template-only";
import Category from "discourse/models/category";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { CategoryRecord } from "discourse/ui-kit/select/recipes/categories/-internals/category-types";
import type { SelectRecord } from "discourse/ui-kit/select/select-engine";

/** A row's description: the category's plain-text description, cut to 200 characters. */
export function categoryDescription(category: Category): string | undefined {
  const text = category.descriptionPlainText;
  if (!text || text === "null") {
    return;
  }
  return text.length > 200 ? `${text.slice(0, 200)}…` : text;
}

/** Builds an engine row while keeping the site's model as the emitted value. */
export function categoryRecord(
  category: Category,
  descriptions = false
): CategoryRecord {
  // Rows come from the site or a search, so the category is saved and has both.
  return {
    id: category.id!,
    name: category.name!,
    category,
    description: descriptions ? categoryDescription(category) : undefined,
  };
}

/**
 * The category a row renders as a badge. Action rows render their icon and label instead,
 * except a family footer, which draws its own category.
 */
function categoryModel(
  item: SelectRecord,
  family?: boolean
): Category | undefined {
  if (item.onSelect && !family) {
    return;
  }
  return (
    (item as CategoryRecord).category ??
    Category.findById(item.id as number | string)
  );
}

/** Narrows shortcut and action labels for templates. */
function name(item: SelectRecord): string {
  return String(item.name ?? "");
}

/** Narrows optional action icons at the rendering boundary. */
function actionIcon(item: SelectRecord): string | undefined {
  return typeof item.icon === "string" ? item.icon : undefined;
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
    record: SelectRecord;
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
  {{#let (categoryModel @record @family) as |category|}}
    {{#if category}}
      {{dCategoryBadge
        category
        allowUncategorized=true
        ancestors=(if @ancestors category.predecessors)
        decorativeEmoji=true
        hasSubcategories=@family
        hideParent=true
        readOnly=@record.disabled
        topicCount=(topicCount category @counts @countSubcategories)
      }}
    {{else}}
      {{#if (actionIcon @record)}}{{dIcon (actionIcon @record)}}{{/if}}
      {{name @record}}
    {{/if}}
  {{/let}}
</template>;
