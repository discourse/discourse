import { hash } from "@ember/helper";
import { eq } from "truth-helpers";
import CategoryChooser from "select-kit/components/category-chooser";

const Category = <template>
  <CategoryChooser
    @value={{@value}}
    @onChange={{@changeValueCallback}}
    @options={{hash allowUncategorized=true none=(eq @setting.default "")}}
  />
</template>;

export default Category;
