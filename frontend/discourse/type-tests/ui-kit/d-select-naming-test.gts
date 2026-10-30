import { hash } from "@ember/helper";
import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";

declare const items: Array<{ id: number; name: string }>;
declare const onChange: (value: unknown) => void;

// The name is only ever spoken, so it is an `aria` argument, as on DButton.
const Test = <template>
  <DSelect
    @items={{items}}
    @onChange={{onChange}}
    @texts={{hash ariaLabel="Fruit"}}
  />
  <DSelect
    @ariaLabelledBy="fruit-caption"
    @items={{items}}
    @onChange={{onChange}}
  />
  <DSelectList
    @items={{items}}
    @onChange={{onChange}}
    @texts={{hash ariaLabel="Fruit"}}
  />
  <DSelectCategory
    @ariaLabelledBy="category-caption"
    @onChange={{onChange}}
    @texts={{hash ariaLabel="Category"}}
  />

  {{! @glint-expect-error - the name is @ariaLabel }}
  <DSelect @items={{items}} @label="Fruit" @onChange={{onChange}} />
  {{! @glint-expect-error - the caption id is @ariaLabelledBy }}
  <DSelect @items={{items}} @labelledBy="caption" @onChange={{onChange}} />
  {{! @glint-expect-error - the name is @ariaLabel }}
  <DSelectList @items={{items}} @label="Fruit" @onChange={{onChange}} />
  {{! @glint-expect-error - the caption id is @ariaLabelledBy }}
  <DSelectCategory @labelledBy="caption" @onChange={{onChange}} />
</template>;

export default Test;
