import { hash } from "@ember/helper";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import { eq } from "discourse/truth-helpers";

const Category = <template>
  <CategoryChooser
    @onChange={{@changeValueCallback}}
    @options={{hash allowUncategorized=true none=(eq @setting.default "")}}
    @value={{@value}}
  />
</template>;

export default Category;
