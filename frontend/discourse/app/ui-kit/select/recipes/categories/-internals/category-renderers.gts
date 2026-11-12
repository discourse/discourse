import type { TemplateOnlyComponent } from "@ember/component/template-only";
import Category from "discourse/models/category";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { CategoryRecord } from "discourse/ui-kit/select/recipes/categories/-internals/category-types";
import {
  type SelectOption,
  selectOption,
  type SelectRecord,
} from "discourse/ui-kit/select/select-engine";

/** An option's description: the category's plain-text description, cut to 200 characters. */
export function categoryDescription(category: Category): string | undefined {
  const text = category.descriptionPlainText;
  if (!text || text === "null") {
    return;
  }
  return text.length > 200 ? `${text.slice(0, 200)}…` : text;
}

/** Builds a select record while keeping the site's model as the emitted value. */
export function categoryRecord(category: Category): CategoryRecord {
  // Records come from the site or a search, so the category is saved and has both.
  return { id: category.id!, name: category.name!, category };
}

/** Lists a category record, described by the category's own description when asked. */
export function categoryOption(
  record: CategoryRecord,
  descriptions: boolean
): SelectOption<CategoryRecord> {
  return selectOption(record, {
    description:
      descriptions && record.category
        ? categoryDescription(record.category)
        : undefined,
  });
}

/**
 * The category a record renders as a badge. Action options render their icon and label instead,
 * except a family footer, which draws its own category.
 */
function categoryModel(
  record: SelectRecord,
  option: SelectOption | undefined,
  family?: boolean
): Category | undefined {
  if (option?.action && !family) {
    return;
  }
  return (
    (record as CategoryRecord).category ??
    Category.findById(record.id as number | string)
  );
}

/** Narrows shortcut and action labels for templates. */
function name(record: SelectRecord): string {
  return String(record.name ?? "");
}

/** Narrows optional action icons at the rendering boundary. */
function actionIcon(record: SelectRecord): string | undefined {
  return typeof record.icon === "string" ? record.icon : undefined;
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
    /** The option drawn, which says whether it's an action or disabled; absent in the selection. */
    option?: SelectOption;
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
  {{#let (categoryModel @record @option @family) as |category|}}
    {{#if category}}
      {{dCategoryBadge
        category
        allowUncategorized=true
        ancestors=(if @ancestors category.predecessors)
        decorativeEmoji=true
        hasSubcategories=@family
        hideParent=true
        readOnly=@option.disabled
        topicCount=(topicCount category @counts @countSubcategories)
      }}
    {{else}}
      {{#if (actionIcon @record)}}{{dIcon (actionIcon @record)}}{{/if}}
      {{name @record}}
    {{/if}}
  {{/let}}
</template>;
