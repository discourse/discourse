import { hash } from "@ember/helper";
import CategoryChooser from "discourse/select-kit/components/category-chooser";

const Category = <template>
  <CategoryChooser
    @onChange={{@changeValueCallback}}
    @options={{hash allowUncategorized=true none=(eq @setting.default "")}}
    @value={{@value}}
  />
</template>;

export default Category;
