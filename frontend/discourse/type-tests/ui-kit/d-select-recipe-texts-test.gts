import { hash } from "@ember/helper";
import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import DSelectCategoryFilter from "discourse/ui-kit/select/recipes/categories/d-select-category-filter";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import DSelectTagFilter from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import DSelectTagIntersection from "discourse/ui-kit/select/recipes/tags/d-select-tag-intersection";
import type { SelectTexts } from "discourse/ui-kit/select/select-engine";

declare const texts: SelectTexts;
declare const onChange: (value: unknown) => void;

// Every recipe takes the call site's texts; the layers a recipe adds for one built on it stay internal.
const Test = <template>
  <DSelectCategory @onChange={{onChange}} @texts={{texts}} />
  <DSelectCategoryFilter @texts={{hash placeholder="anywhere"}} />
  <DSelectTag @texts={{hash placeholder="Topic tags…"}} />
  <DSelectTagFilter @texts={{texts}} />
  <DSelectTagGroup @texts={{texts}} />
  <DSelectTagIntersection @texts={{texts}} />

  {{! @glint-expect-error - the tag filter holds one tag; the intersection holds several }}
  <DSelectTagFilter @multiple={{true}} />
  {{! @glint-expect-error - only a recipe built on the tag field adds its texts }}
  <DSelectTag @kindTexts={{texts}} />
  {{! @glint-expect-error - only a recipe built on the tag field turns the requirement off }}
  <DSelectTag @requirementPlaceholders={{false}} />
</template>;

// A misspelled key fails on every component, and a recipe's own key only works on that recipe.
const Keys = <template>
  <DSelect @texts={{hash noResults="ok" addMorePlaceholder="ok"}} />
  {{! @glint-expect-error - not an engine text }}
  <DSelect @texts={{hash noResultz="typo"}} />
  {{! @glint-expect-error - a recipe's text, not the engine's }}
  <DSelect @texts={{hash familyFooter="x"}} />
  {{! @glint-expect-error - not an engine text }}
  <DSelectList @texts={{hash noResultz="typo"}} />

  <DSelectCategory
    @onChange={{onChange}}
    @texts={{hash familyFooter="x" readOnlyDescription="y" noResults="z"}}
  />
  {{! @glint-expect-error - not a category text }}
  <DSelectCategory @onChange={{onChange}} @texts={{hash familyFootr="x"}} />
  <DSelectCategoryFilter @texts={{hash removeFilter="x" noSubcategories="y"}} />
  {{! @glint-expect-error - a tag filter text }}
  <DSelectCategoryFilter @texts={{hash noTags="x"}} />

  <DSelectTag
    @texts={{hash addMoreTags="x" requiredTagGroup="y" tagCount="z"}}
  />
  {{! @glint-expect-error - a tag filter text }}
  <DSelectTag @texts={{hash noTags="x"}} />
  <DSelectTagFilter
    @texts={{hash noTags="x" addMoreTags="y" removeFilter="z"}}
  />
  {{! @glint-expect-error - a category filter text }}
  <DSelectTagFilter @texts={{hash noSubcategories="x"}} />
  {{! @glint-expect-error - a tag filter text }}
  <DSelectTagGroup @texts={{hash noTags="x"}} />
  <DSelectTagIntersection @texts={{hash addMoreTags="x" placeholder="y"}} />
  {{! @glint-expect-error - a tag filter's shortcut text }}
  <DSelectTagIntersection @texts={{hash noTags="x"}} />
</template>;

export default [Test, Keys];
