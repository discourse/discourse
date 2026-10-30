import { hash } from "@ember/helper";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import DSelectCategoryFilter from "discourse/ui-kit/select/recipes/categories/d-select-category-filter";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import DSelectTagFilter from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
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

  {{! @glint-expect-error - only a recipe built on the tag field adds its texts }}
  <DSelectTag @kindTexts={{texts}} />
  {{! @glint-expect-error - only a recipe built on the tag field turns the requirement off }}
  <DSelectTag @requirementPlaceholders={{false}} />
</template>;

export default Test;
